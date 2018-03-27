# chatbot
## 华侨大学2018年省级立项（智能问答机器人——IOS客户端）
指导教师：王成      E-mail：wc071@163.com

小组成员：陈兴雷（算法）、谢佳培（IOS客户端）、石林鹭（UI界面）

## 开发流程
#### 环境
* 设计模式：MVC
* 语言：Swift 4.0        
* IDE:Xcode 9.0   
* 客户端：IOS 11.0

#### 框架
- ApiAI：谷歌提供的聊天机器人API
- RealmSwift：储存聊天信息的云端数据库
- JSQMessagesViewController：提供聊天界面
- Alamofire和SwiftyJSON：异步网络请求
- AVFoundation：语音

##### 导入框架
```
# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

target 'chatbot' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  # Pods for chatbot
  pod 'ApiAI'
  pod 'JSQMessagesViewController'
  pod 'RealmSwift'
  pod 'Alamofire', '~> 4.7'
  pod 'SwiftyJSON'
end
```
      
### 第一步
#### AppDelegate文件：

##### 获取谷歌client的API
```
        let configuration = AIDefaultConfiguration()
        configuration.clientAccessToken = "08f63091e13b420bbae91927859b1a24"
        
        let apiai = ApiAI.shared()
        apiai?.configuration = configuration
```    

#### ViewController文件：

### 第二步

##### 使用JSQMessagesViewController搭建对话UI界面
```
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
```

### 第三步

#### realmSwiftObject文件:

##### 数据库中信息的model
```
class Message: Object{
    @objc dynamic var senderName = ""
    @objc dynamic var senderID = ""
    @objc dynamic var senderMessage = ""
}
```

#### ViewController文件：

##### 对话者的model
```
//使用者
struct User {
    let id: String
    let name: String
    
}
//使用者实例化
let user1 = User(id: "1", name: "XieJiaPei")
let user2 = User(id: "2", name: "HeSiYu")
    
var currentUser: User {
    return user1
}
```

##### 使用RealmSwift从云端数据库存取对话信息
```
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
                self.speechAndText(text: responseFromAI)
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
```
### 第四步

#### 使用网络服务
```
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
```

### 第五步

#### 使用Alamofire和SwiftyJSON框架进行网络优化
```
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
```        

### 第六步

#### 使用AVFoundation框架支持语音功能
```
    //语音
    let speechSynthesizer = AVSpeechSynthesizer()
    func speechAndText(text: String) {
        let speechUtterance = AVSpeechUtterance(string: text)
        speechSynthesizer.speak(speechUtterance)
    }
```

