//
//  NVEditItemViewController.swift
//  Swift.nV
//
//  Created by Seth Law on 7/2/14.
//  Copyright (c) 2014 nVisium. All rights reserved.
//

import UIKit

class NVEditItemViewController: UIViewController, UITextViewDelegate {

    @IBOutlet weak var nameField : UITextField!
    @IBOutlet weak var valueField : UITextView!
    @IBOutlet weak var notesField : UITextView!
    @IBOutlet weak var createdLabel : UILabel!
    @IBOutlet weak var showButton : UIButton!
    @IBOutlet weak var editItemScroll: UIScrollView!
    
    var item : Item!
    var data = NSMutableData()

    var decryptedVal : NSString = ""
    var showValue:Bool = false
    var oldChecksum = ""
    
    var appUser : User!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if (item != nil) {
            nameField.text = item.name
            self.decryptedVal = decryptString(item.value)
            self.oldChecksum = item.checksum
            valueField.text = String(count:decryptedVal.length,repeatedValue:"*" as Character)
            notesField.text = item.notes
            let df : NSDateFormatter = NSDateFormatter()
            df.dateFormat = "dd/MM/yyyy"
            
            createdLabel.text = NSString(format: "created %@",df.stringFromDate(item.created)) as String
        } else {
            NSLog("NVEditItemViewController: Item is nil")
        }

        // Do any additional setup after loading the view.
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        editItemScroll.contentSize = CGSizeMake(320, 750)
    }

    //- (BOOL)textViewShouldBeginEditing:(UITextView *)textView
    
    func textViewShouldBeginEditing(textView:UITextView) -> Bool {
        valueField.text = decryptedVal as String
        showValue = true
        return true
    }
    
    func textViewShouldEndEditing(textView:UITextView) -> Bool {
        valueField.text = String(count:decryptedVal.length,repeatedValue:"*" as Character)
        showValue = false
        return true
    }
    
    //- (void)textViewDidChange:(UITextView *)textView
    
    func textViewDidChange(textView:UITextView) {
        self.decryptedVal = valueField.text
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func saveItem(sender : AnyObject) {
        item.name = nameField.text!
        if showValue {
            item.value = encryptString(valueField.text)
        } else {
            item.value = encryptString(decryptedVal as String)
        }
        
        item.notes = notesField.text
        item.checksum = generateChecksum(item)
        
        if item.checksum != self.oldChecksum {
            let envPlist = NSBundle.mainBundle().pathForResource("Environment", ofType: "plist")
            let envs = NSDictionary(contentsOfFile: envPlist!)!
            
            //var itvc : NVItemsTableViewController = self.parentViewController as NVItemsTableViewController
            //self.appUser = itvc.appUser
            
            let secret = [
                "name": item.name,
                "contents": item.value,
                "checksum": item.checksum,
                "version": item.version,
                "notes": item.notes,
                "user_id": self.appUser.user_id
            ]
            
            var j: NSData?
            do {
                j = try NSJSONSerialization.dataWithJSONObject(secret, options: NSJSONWritingOptions.PrettyPrinted)
            } catch let error as NSError {
                NSLog("Error: %@", error.localizedDescription)
                j = nil
            }
            
            let tURL = envs.valueForKey("UpdateSecretURL") as! String
            let upURL = "\(tURL)\(item.item_id)"
            let secURL = NSURL(string: upURL)
            
            NSLog("Updating secret for user with checksum: \(item.checksum)")
            
            let request = NSMutableURLRequest(URL: secURL!)
            request.HTTPMethod = "PUT"
            request.HTTPBody = j
            
            _ = NSURLConnection(request: request, delegate: self, startImmediately: true)
            
            self.saveContext()
            self.clearform()
            
        } else {
            self.saveContext()
            self.clearform()
            self.dismissViewControllerAnimated(true, completion: nil)
        }
        

    }
    
    func saveContext() {
        let delegate : AppDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        let context = delegate.managedObjectContext!
        var err :NSError?
        do {
            try context.save()
        } catch let error as NSError {
            err = error
        }
        if err != nil {
            NSLog("%@",err!)
        }
    }
    
    @IBAction func deleteItem(sender : AnyObject) {
        let delegate : AppDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        let context = delegate.managedObjectContext!
        
        let alert : UIAlertController = UIAlertController(title: "Delete Item", message: "Are you sure?", preferredStyle: UIAlertControllerStyle.Alert)
        let yesItem : UIAlertAction = UIAlertAction(title: "Yes", style: UIAlertActionStyle.Default, handler: {
            (action:UIAlertAction) in
            NSLog("Delete item \(self.item.name)")
            self.clearform()
            context.deleteObject(self.item)
            do {
                try context.save()
            } catch let error as NSError {
                NSLog("Error: %@", error)
            } catch {
                fatalError()
            }
            self.dismissViewControllerAnimated(true, completion: nil)

            })
        let noItem : UIAlertAction = UIAlertAction(title: "No", style: UIAlertActionStyle.Default, handler: {
            (action:UIAlertAction) in
            alert.dismissViewControllerAnimated(true, completion: nil)
            })
        
        alert.addAction(yesItem)
        alert.addAction(noItem)
        
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    @IBAction func copyValue(sender : AnyObject) {
        let pb :UIPasteboard = UIPasteboard.generalPasteboard()
        pb.string = self.decryptedVal as String
    }
    
    func clearform () {
        nameField.text = ""
        valueField.text=""
        notesField.text=""
        createdLabel.text=""
    }
    
    // NSURLConnectionDataDelegate Classes
    
    func connection(con: NSURLConnection!, didReceiveData _data:NSData!) {
        //NSLog("didReceiveData")
        self.data.appendData(_data)
    }
    
    /* func connection(con: NSURLConnection!, didReceiveResponse _response:NSURLResponse!) {
    NSLog("didReceiveResponse")
    var response : NSHTTPURLResponse = _response
    
    }*/
    
    func connectionDidFinishLoading(con: NSURLConnection!) {
        
        let res : NSDictionary = (try! NSJSONSerialization.JSONObjectWithData(self.data, options: NSJSONReadingOptions.MutableContainers)) as! NSDictionary
        
        if (res["id"] != nil) {
            let delegate : AppDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
            let context = delegate.managedObjectContext!
            self.item.item_id = res["id"] as! NSNumber
            do {
                try context.save()
            } catch let error as NSError {
                NSLog("Error saving context: %@", error)
            }
            NSLog("Update Item \(self.item.item_id) in database")
        } else {
            self.data.setData(NSData())
            NSLog("No ID on the response, strange")
        }
        
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func connection(connection: NSURLConnection!, didFailWithError error: NSError!) {
        //self.message.text = "Connection to API failed"
        NSLog("%@",error!)
    }
    
    /*
    // #pragma mark - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue?, sender: AnyObject?) {
        // Get the new view controller using [segue destinationViewController].
        // Pass the selected object to the new view controller.
    }
    */

}
