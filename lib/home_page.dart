import 'package:aiapp/feature_box.dart';
import 'package:aiapp/pallete.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return  Scaffold(
      appBar: AppBar(
        title: const Text('Ai App'),
        leading: const Icon(Icons.menu),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Stack(
            children: [
              Center(
                child: Container(
                  
                  width: 120,
                  height: 120,
                  margin: const EdgeInsets.only( top: 4),
                  decoration: BoxDecoration(
                    color: Pallete.assistantCircleColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: AssetImage('assets/images/virtualAssistant.png'),
                      fit: BoxFit.cover, // This ensures the image covers the container
                    ),
                  ),
                ),
              )

            ],
          ),
          // Chat Bubble
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 10,

            ),
            margin: const EdgeInsets.symmetric(horizontal: 40).copyWith(
              top: 30
            ),
            decoration: BoxDecoration(
              border: Border.all(
                color: Pallete.borderColor,
              ),
              borderRadius: BorderRadius.circular(20).copyWith(
                topLeft: Radius.zero,
                

              )
            ),

            child: const Padding(
              padding:  EdgeInsets.symmetric(vertical: 10),
              child: Text("Good Morning, what task can i do for you?",
              style: TextStyle(
                color: Pallete.mainFontColor,
                fontSize: 25,
                fontFamily: 'Cera Pro'
              )),
            ) ,
          ),
          // suggestion list 
          Container(
            padding: const EdgeInsets.all(10),
            alignment: Alignment.centerLeft,
            margin: const EdgeInsets.only(
              top: 10,
              left: 22
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: const Text("Here are few commands",
              style: TextStyle(
                fontFamily: 'Cera Pro', 
                fontSize: 20, 
                color: Pallete.mainFontColor, 
                fontWeight: FontWeight.bold
                ),
                ),
            ),
          ),
          // feature list 
          Column(
            children: const [
              FeatureBox(color: Pallete.firstSuggestionBoxColor, 
              headerText: 'ChatGPT',
              descriptionText: 'A smarter way to stay organized and informed with ChatGPT',
              ),
              FeatureBox(color: Pallete.secondSuggestionBoxColor, 
              headerText: 'Dall-E',
              descriptionText: 'Get Inspired and stay creative with your personal assistant provided by Dall-E',
              ),              
              FeatureBox(color: Pallete.firstSuggestionBoxColor, 
              headerText: 'Smart Voice Assistant',
              descriptionText: 'Get the bets of the both worlds with a voice assistant powered by Dall-E and ChatGPT',
              ),                 
            ],
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Pallete.firstSuggestionBoxColor,
        onPressed: (){},

        child: const Icon(Icons.mic),

      ),
    ); // use const to perform code better

  }
}