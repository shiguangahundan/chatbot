//
//  ViewController.swift
//  chatbot
//
//  Created by Xie Jia Pei on 22/03/2018.
//  Copyright © 2018 Xie Jia Pei. All rights reserved.
//

import UIKit
import ApiAI
import RealmSwift
import JSQMessagesViewController
import Alamofire
import SwiftyJSON

//使用者
struct User {
    let id: String
    let name: String
    
}

class ViewController: JSQMessagesViewController {
    
    //https://www.googleapis.com/youtube/v3/search?part=snippet&q=whalien%2052&type=video&key=AIzaSyA72fWyfXOvHfUBlFpJm38hwn2MYgu15jE
    //google cloud api key
    let apiKey = "AIzaSyA72fWyfXOvHfUBlFpJm38hwn2MYgu15jE"
    let youtubeURL = "https://www.youtube.com/watch?v="
    
    //储存产生的对话
    var messages = [JSQMessage]()
    
    //使用者
    let user1 = User(id: "1", name: "XieJiaPei")
    let user2 = User(id: "2", name: "HeSiYu")
    
    var currentUser: User {
        return user1
    }
}

extension ViewController{
    override func viewDidLoad() {
        super.viewDidLoad()
        self.senderId = currentUser.id
        self.senderDisplayName = currentUser.name
        
        //获取先前数据库中的信息
        queryAllMessages()
    }
}

extension ViewController{
    //发送消息时候触发
    override func didPressSend(_ button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: Date!) {
        
        //储存信息到云端数据库
        self.addMessage(senderDisplayName, senderId, senderMessage: text)
        
        //储存信息到JSQMessages Array
        let message = JSQMessage(senderId: senderId, displayName: senderDisplayName, text: text)
        messages.append(message!)
        
        //调用发送信息给client的函数
        handleSendMessageToBot(text)
        
        //更新UI
        finishSendingMessage() 
    }
    //气泡姓名标签
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, attributedTextForMessageBubbleTopLabelAt indexPath: IndexPath!) -> NSAttributedString! {
        let message = messages[indexPath.row]
        let messageUserName = message.senderDisplayName
        return NSAttributedString(string:messageUserName! )
    }
    //对话气泡大小高度
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout!, heightForMessageBubbleTopLabelAt indexPath: IndexPath!) -> CGFloat {
        return 15
    }
    //使用者头像
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAt indexPath: IndexPath!) -> JSQMessageAvatarImageDataSource! {
        return nil
    }
    //气泡的尾巴方向
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageBubbleImageDataForItemAt indexPath: IndexPath!) -> JSQMessageBubbleImageDataSource! {
        let bubbleFactory = JSQMessagesBubbleImageFactory()
        let message = messages[indexPath.row]
        if currentUser.id == message.senderId{
            return bubbleFactory?.outgoingMessagesBubbleImage(with:  UIColor.green)
        }else{
            return bubbleFactory?.incomingMessagesBubbleImage(with: UIColor.blue)
        }
    }
    //气泡数量
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return messages.count
    }
    //气泡里的信息
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageDataForItemAt indexPath: IndexPath!) -> JSQMessageData! {
        return messages[indexPath.row]
    }
}
//数据储存相关函数
extension ViewController{
    func addMessage(_ senderName: String,_ senderID:String, senderMessage: String)
    {
        //获取信息
        let message = Message()
        message.senderID = senderID
        message.senderName = senderName
        message.senderMessage = senderMessage
        //信息写进realm里
        let realm = try! Realm()
        try! realm.write {
            realm.add(message)
        }
    }
    //从Realm读出信息
    func queryAllMessages(){
        let realm = try! Realm()
        let messages = realm.objects(Message.self)
        
        for message in messages{
            let msg = JSQMessage(senderId: message.senderID, displayName: message.senderName, text: message.senderMessage)
            self.messages.append(msg!)
        }
    }
    //协助传送信息给client
    
    func handleSendMessageToBot(_ message: String)
    {
        let request = ApiAI.shared().textRequest()
        request?.query = message
        request?.setMappedCompletionBlockSuccess({ (request, response) in
            let response = response as! AIResponse
            //捕获信息
            if let responseFromAI = response.result.fulfillment.speech as? String{
                self.handleStoreBotMsg(responseFromAI)
            }
            //捕获参数
            if let singerName = (response.result.parameters as! Dictionary<String,AIResponseParameter>)["singer"], singerName.stringValue != "" {
                if let songName = (response.result.parameters as! Dictionary<String,AIResponseParameter>)["song"], singerName.stringValue != "" {
                    print("singer name:\(singerName.stringValue!)")
                    print("song name:\(songName.stringValue!)")
                    self.handleSearchYoutubeWith(singerName.stringValue!,songName.stringValue!)
                }
            }
        }, failure: { (request, error) in
            print(error!)
            print("wrong")
        })
        //将信息传送给机器人
        ApiAI.shared().enqueue(request)
    }
 
    //协助储存client的回应
    func handleStoreBotMsg(_ botMsg: String)
    {
        //将message储存到REALM
        addMessage(user2.name, user2.id, senderMessage: botMsg)
        //将message储存到JSQMessage array
        let botMessage = JSQMessage(senderId: user2.id, displayName: user2.name, text: botMsg)
        messages.append(botMessage!)
        finishSendingMessage()
    }
    
    //回传URL给用户
    func handleGiveVideoUrl(_ urlString: String){
        //储存client回传给的信息
        addMessage(user2.name, user2.id, senderMessage: urlString)
        //写入信息
        let message = JSQMessage(senderId: user2.id, displayName: user2.name, text: urlString)
        messages.append(message!)
        finishSendingMessage()
    }
}

//用于youtube的函数
extension ViewController{
    //获得url
    func handleSearchYoutubeWith(_ singerName: String,_ songName: String){

        //参数
        let query: String = singerName + " " + songName
        let parameter: Parameters = ["part":"snippet","q":query,"type":"video","key":apiKey]
        
        //调用request函数
        Alamofire.request("https://www.googleapis.com/youtube/v3/search", method: .get, parameters: parameter, encoding: URLEncoding.default, headers: nil).responseJSON { (response) in
            switch response.result{
                //使用SWIFTYJSON框架
            case .success(let value):
                let json = JSON(value)
                if let videoId = json["items"][0]["id"]["videoId"].string{
                    print("videoId:",videoId)
                    let videoURL = self.youtubeURL + videoId
                    self.handleGiveVideoUrl(videoURL)
                }
                break
            case .failure(let error):
                print("error:\(error)")
                break
            }
        }
        
//优化——通过框架来连接网络
        /*
        //处理关键字中的空格
        let singer = singerName.replacingOccurrences(of: " ", with: "%20")
        let song = songName.replacingOccurrences(of: " ", with: "%20")
        //url字符串
        let urlString: String = "https://www.googleapis.com/youtube/v3/search?part=snippet&q=\(singer)%20\(song)&type=video&key=\(apiKey)"
        let targetURL = URL(string: urlString)
        
        
        
        //送出request
        performGetRequest(targetURL: targetURL!) { (data, HTTPStatusCode, error) in
            //一切正常
            if HTTPStatusCode == 200 && error == nil{
                //解析得到的JSON
                do{
                    let resultDictionry = try JSONSerialization.jsonObject(with: data!, options: []) as! Dictionary<String,AnyObject>
                    //转换为字典，存取项目items
                    let items = resultDictionry["items"] as! Array<Dictionary<String,AnyObject>>
                    //存取videoID
                    if let videoId = (items.first?["id"] as! Dictionary<String,AnyObject>)["videoId"]{
                        print("video id:\(videoId)")
                        
                        let videoURL = self.youtubeURL + (videoId as! String)
                        self.handleGiveVideoUrl(videoURL)
                    }
                }catch{
                    print(error)
                }
            }
        }
        */
    }
    //发送请求
    func performGetRequest(targetURL: URL,completion:@escaping (_ date:Data?,_ HTTPStatusCode: Int,_ error:Error?) -> Void){
        //建立request
        var request = URLRequest(url:targetURL)
        request.httpMethod = "GET"
        //建立session
        let sessionConfiguration = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfiguration)
        //建立task
        let task = session.dataTask(with: request) { (data: Data?, response: URLResponse?, error: Error?) in
            completion(data,(response as! HTTPURLResponse).statusCode,error)
        }
        task.resume()
    }
}
