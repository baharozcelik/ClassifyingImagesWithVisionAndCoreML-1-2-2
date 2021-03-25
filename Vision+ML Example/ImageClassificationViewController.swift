//
//  ImageClassificationViewController.swift
//  Vision+ML Example
//
//  Created by Bahar on 25.11.2020.
//  Copyright © 2020 Apple. All rights reserved.
//

import UIKit
import CoreML
import Vision
import ImageIO
import Firebase


class ImageClassificationViewController: UIViewController {
    // MARK: - IBOutlets

    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var cameraButton: UIBarButtonItem!
    @IBOutlet weak var classificationLabel: UILabel!

    
    override func viewDidLoad() {
        super.viewDidLoad()
        

        
    }
    
    func FotolarDatabase(for image: UIImage) {
            
            guard let uploadData = UIImageJPEGRepresentation(image, 80) else { return }
            
            navigationItem.rightBarButtonItem?.isEnabled = false
            
            let filename = NSUUID().uuidString
            
            let storageRef = Storage.storage().reference().child("posts").child(filename)
            storageRef.putData(uploadData, metadata: nil) { (metadata, error) in
                
                if let error = error {
                    self.navigationItem.rightBarButtonItem?.isEnabled = true
                    print("Failed to upload post image:", error)
                    return
                }
                
                storageRef.downloadURL(completion: { (downloadURL, error) in
                    if let error = error {
                        print("Failed to fetch downloadURL", error)
                        return
                    }
                    let imageUrl = downloadURL?.absoluteString
                    
                    let post = ["image": imageUrl!] as  [String : Any]
                    Database.database().reference().child("resimler").childByAutoId().setValue(post)
                    
                    print("Succesfully uploaded post image:", imageUrl)
                    
                })
            }
        }

    // MARK: - Image Classification
    // Model'in kurulumu
    // CoreML modeline bir resim analizi çağrısı yapmak için Vision CoreMLRequest olusturulur. Lazy olmasının sebebi nesnenin kullanımına ihtiyac oldugu anda olusturulmasını saglamaktır.
    
    // Model çalıştırılıp sonuç döndüğünde proseccClassifications metoduna geçilir.
    // ML modeli input olarak belirli bir en boy aralıgında resimler bekler ama yuklenen fotoğraflar farklı en boy oranında olabilir.
    //Burada Vision kutuphanesi resmi ölçeklendirmek ve kırmak icin secenek sunar. (imageCropAndScaleOption )
    
    /// - Tag: MLModelSetup
    lazy var classificationRequest: VNCoreMLRequest = {
        do {
            /*
             Use the Swift class `MobileNet` Core ML generates from the model.
             */
            let model = try VNCoreMLModel(for: MobileNet().model)
            
            let request = VNCoreMLRequest(model: model, completionHandler: { [weak self] request, error in
                self?.processClassifications(for: request, error: error)
            })
            request.imageCropAndScaleOption = .centerCrop
            return request
        } catch {
            fatalError("Failed to load Vision ML model: \(error)")
        }
    }()
    
    /// - Tag: PerformRequests
    // resim yuklendiginde UpdateClassifications methodu cagrılır. Bu metotta VNImageRequestHandler objesi olusturulur.
    // VNImageRequestHandler resme iliskin resim analizlerini yonetir. Parametre olarak işlenecek resmi ve resmin oryantasyonunu alır.
    // perform methodu cagrılarak Vision request sıraya sokulur.
    
    
    func updateClassifications(for image: UIImage) {
        classificationLabel.text = "Classifying..."
        
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        guard let ciImage = CIImage(image: image) else { fatalError("Unable to create \(CIImage.self) from \(image).") }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation)
            do {
                try handler.perform([self.classificationRequest])
            } catch {
                /*
                 This handler catches general image processing errors. The `classificationRequest`'s
                 completion handler `processClassifications(_:error:)` catches errors specific
                 to processing that request.
                 */
                print("Failed to perform classification.\n\(error.localizedDescription)")
            }
        }
    }
    
    /// Updates the UI with the results of the classification.
    ///  Model her cağrıldığında çalışan metod.
    ///  Model calıstıgında dönen VNRequest'in içinde results dizisi bulunmaktadır.
    ///  Bu dizide resmin tahmin sonucları yer almaktadır. En emin olunan sınıf en üsttedir.
    ///  Prefix metodu ile olasılıgı en yuksek olan 2 sınıf alınarak ekranda gosterilmektedir.
    ///
    /// - Tag: ProcessClassifications
    func processClassifications(for request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            guard let results = request.results else {
                self.classificationLabel.text = "Unable to classify image.\n\(error!.localizedDescription)"
                return
            }
            // The `results` will always be `VNClassificationObservation`s, as specified by the Core ML model in this project.
            let classifications = results as! [VNClassificationObservation]
        
            if classifications.isEmpty {
                self.classificationLabel.text = "Nothing recognized."
            } else {
                // Display top classifications ranked by confidence in the UI.
                let topClassifications = classifications.prefix(2)
                let descriptions = topClassifications.map { classification in
                    // Formats the classification for display; e.g. "(0.37) cliff, drop, drop-off".
                   return String(format: "  (%.2f) %@", classification.confidence, classification.identifier)
                }
                self.classificationLabel.text = "Classification:\n" + descriptions.joined(separator: "\n")
            }
        }
    }
    
    // MARK: - Photo Actions
    
    @IBAction func takePicture() {
        // Show options for the source picker only if the camera is available.
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            presentPhotoPicker(sourceType: .photoLibrary)
            return
        }
        
        let photoSourcePicker = UIAlertController()
        let takePhoto = UIAlertAction(title: "Take Photo", style: .default) { [unowned self] _ in
            self.presentPhotoPicker(sourceType: .camera)
        }
        let choosePhoto = UIAlertAction(title: "Choose Photo", style: .default) { [unowned self] _ in
            self.presentPhotoPicker(sourceType: .photoLibrary)
        }
        
        photoSourcePicker.addAction(takePhoto)
        photoSourcePicker.addAction(choosePhoto)
        photoSourcePicker.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        present(photoSourcePicker, animated: true)
    }
    
    func presentPhotoPicker(sourceType: UIImagePickerControllerSourceType) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = sourceType
        present(picker, animated: true)
    }
}

extension ImageClassificationViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    // MARK: - Handling Image Picker Selection

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String: Any]) {
        picker.dismiss(animated: true)
        
        // We always expect `imagePickerController(:didFinishPickingMediaWithInfo:)` to supply the original image.
        let image = info[UIImagePickerControllerOriginalImage] as! UIImage
        imageView.image = image
        FotolarDatabase(for: image)
        updateClassifications(for: image)
    }
}
