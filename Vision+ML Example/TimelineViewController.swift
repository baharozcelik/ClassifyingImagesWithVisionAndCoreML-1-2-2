//
//  TimelineViewController.swift
//  Vision+ML Example
//
//  Created by Bahar on 25.11.2020.
//  Copyright © 2020 Apple. All rights reserved.
//
import UIKit
import Firebase
import FirebaseDatabase
//Resimlerin url olarak indirip sayfamızda gözümeksini sağlayan framework'ü dahil ediyoruz
import SDWebImage


class TimelineViewController : UIViewController, UICollectionViewDelegate, UICollectionViewDataSource {
    
    @IBOutlet weak var collectionView: UICollectionView!
    var refresher:UIRefreshControl!

    
    var ulkeler: [String] = [String]()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        
        self.refresher = UIRefreshControl()
        self.collectionView!.alwaysBounceVertical = true
        self.refresher.tintColor = UIColor.red
        self.refresher.addTarget(self, action: #selector(yenileme), for: .valueChanged)
        self.collectionView!.addSubview(refresher)
        
 
        collectionView.delegate = self
        collectionView.dataSource = self
        
        resimdata()
        
    }
    @objc func yenileme(){
        ulkeler.removeAll()
        resimdata()
      //  self.collectionView!.refreshControl?.endRefreshing()
        
    }
    @objc func resimdata(){
        //Veritabanından resimlerin linkine çekiyoruz
        Database.database().reference().child("resimler").observe(DataEventType.childAdded) { (snapchat) in
            let values = snapchat.value! as! NSDictionary
            for _ in values
            {
                let resim = values["image"]
                //resimArraye resimlerin linkleri tek tek ekliyoruz
                self.ulkeler.append(resim as! String)
            }
            self.ulkeler.reverse()
            self.collectionView.reloadData()
            }
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return ulkeler.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ulkeHucre", for: indexPath) as! CollectionViewHucre
        
        cell.postLabel.sd_setImage(with: URL(string: self.ulkeler[indexPath.row]))

    //    cell.hucreLabel.text = ulkeler[indexPath.row]
        
        return cell
    }
 }

