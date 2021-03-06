import 'package:flutter/material.dart';
import 'package:firebase_firestore/firebase_firestore.dart';
import 'package:firebase_firestore/src/utils/push_id_generator.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:image_picker/image_picker.dart';

void main(){
  runApp(new MaterialApp(
    title: "FriendlyChat Firestore",
    theme: new ThemeData(
      primarySwatch: Colors.red,
      accentColor: Colors.orangeAccent[400],
    ),
    home: new MyApp(),
  ));
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<MyApp> {

  final analitycs = new FirebaseAnalytics();

  final googleSignIn = new GoogleSignIn();

  final auth = FirebaseAuth.instance;

  var collection = Firestore.instance.collection("messages");

  final TextEditingController _textController = new TextEditingController();

  bool _isComposing = false;

  String id_message = PushIdGenerator.generatePushChildName();

  Future<Null> _handleSubmitted(String text) async{

    _textController.clear();

    setState((){
      _isComposing = false;
    });

    await _ensureLoggedIn();

    _sendMessage(text: text);
  }

  void _sendMessage({String text, String imageUrl}) {
    collection.document(id_message).setData({
      'id': id_message,
      'senderImage': googleSignIn.currentUser.photoUrl,
      'sender': googleSignIn.currentUser.displayName,
      'text': text,
      'imageUrl': imageUrl,
      'timestamp': new DateTime.now().millisecondsSinceEpoch
    });
    analitycs.logEvent(name: "send_message");
  }

  Future<Null> _ensureLoggedIn() async{

    GoogleSignInAccount user = googleSignIn.currentUser;

    if(user == null)
      user = await googleSignIn.signInSilently();

    if(user == null){
      await googleSignIn.signIn();
      analitycs.logLogin();
    }

    if(await auth.currentUser() == null){
      GoogleSignInAuthentication credentials = await googleSignIn.currentUser.authentication;
      await auth.signInWithGoogle(idToken: credentials.idToken, accessToken: credentials.accessToken,);
    }
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text("Friendly Chat Firestore"),
      ),
      body: new Container(
        child: new Column(
          children: <Widget>[
            new Flexible(
                child: new ChatMessage()
            ),
            new Divider(height: 1.0),
            new Container(
                decoration: new BoxDecoration(
                    color: Theme.of(context).cardColor
                ),
                child: _buildTextComposer()
            ),
          ],
        ),
      ),
    );
  }

  _buildTextComposer() {
    return new IconTheme(
        data: new IconThemeData(
          color: Theme.of(context).accentColor
        ),
        child: new Container(
          child: new Row(
            children: <Widget>[
              new Container(
                margin: new EdgeInsets.symmetric(horizontal: 4.0),
                child: new IconButton(
                    icon: new Icon(Icons.photo_camera),
                    onPressed: () async{
                      await _ensureLoggedIn();
                      File imageFile = await ImagePicker.pickImage();
                      int random = new Random().nextInt(100000);
                      StorageReference ref = FirebaseStorage.instance.ref().child("image_$random.jpg");
                      StorageUploadTask uploadTask = ref.put(imageFile);
                      Uri downloadUrl = (await uploadTask.future).downloadUrl;
                      _sendMessage(imageUrl: downloadUrl.toString());
                    }
                ),
              ),
              new Flexible(child: new TextField(
                  controller: _textController,
                  onChanged: (String text){
                    setState((){
                      _isComposing = text.length > 0;
                    });
                  },
                  onSubmitted: _handleSubmitted,
                  decoration: new InputDecoration.collapsed(hintText: "Send a message")
              )
              ),
              new Container(
                margin: new EdgeInsets.symmetric(horizontal: 4.0),
                child: new IconButton(
                    icon: new Icon(Icons.send),
                    onPressed: _isComposing ?
                        () => _handleSubmitted(_textController.text):
                        null
                ),
              )
            ],
          ),
        )
    );
  }
}

class ChatMessage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new StreamBuilder(
      stream: Firestore.instance.collection('messages').snapshots,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return new Text('Loading...');
        return new ListView(
          reverse: true,
          children: snapshot.data.documents.map((document){
            return new Container(
              margin: const EdgeInsets.symmetric(vertical: 10.0),
              child: new Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  new Container(
                    margin: const EdgeInsets.only(right: 16.0),
                    child: document['senderImage'] != null ?
                    new CircleAvatar(
                      backgroundImage: new NetworkImage(document['senderImage']),):
                    new CircleAvatar(
                    child: new Text(document['sender'][0],),),
                  ),
                  new Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      new Text(document['sender'],
                        style: Theme.of(context).textTheme.subhead,
                      ),
                      new Container(
                        margin: const EdgeInsets.only(top: 5.0),
                        child: document['imageUrl'] != null?
                        new Image.network(document['imageUrl'], width: 250.0,):
                        new Text(document['text'])
                      )
                    ],
                  )
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
