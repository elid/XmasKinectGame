// Kinect Physics Example by Amnon Owed (15/09/12)

//edited by Arindam Sen
 
// import libraries
import processing.opengl.*; // opengl
import SimpleOpenNI.*; // kinect
import blobDetection.*; // blobs
import toxi.geom.*; // toxiclibs shapes and vectors
import toxi.processing.*; // toxiclibs display
import shiffman.box2d.*; // shiffman's jbox2d helper library
import org.jbox2d.collision.shapes.*; // jbox2d
import org.jbox2d.dynamics.joints.*;
import org.jbox2d.common.*; // jbox2d
import org.jbox2d.dynamics.*; // jbox2d

import controlP5.*;
ControlP5 cp5;

// Countdown Timer
import com.dhchoi.CountdownTimer;
CountdownTimer timer;
String timerCallbackInfo = "";

// declare SimpleOpenNI object
SimpleOpenNI context;
// declare BlobDetection object
BlobDetection theBlobDetection;
// ToxiclibsSupport for displaying polygons
ToxiclibsSupport gfx;
// declare custom PolygonBlob object (see class for more info)
PolygonBlob poly;
 
// PImage to hold incoming imagery and smaller one for blob detection
PImage blobs;
// the kinect's dimensions to be used later on for calculations
int kinectWidth = 640;
int kinectHeight = 480;
PImage cam;

// to center and rescale from 640x480 to higher custom resolutions
float reScale;
 
// background and blob color
color bgColor, blobColor;
// three color palettes (artifact from me storingmany interesting color palettes as strings in an external data file ;-)
String[] palettes = {
  "-1117720,-13683658,-8410437,-9998215,-1849945,-5517090,-4250587,-14178341,-5804972,-3498634", 
  "-67879,-9633503,-8858441,-144382,-4996094,-16604779,-588031", 
  "-1978728,-724510,-15131349,-13932461,-4741770,-9232823,-3195858,-8989771,-2850983,-10314372"
};
color[] colorPalette;
 
// the main PBox2D object in which all the physics-based stuff is happening
Box2DProcessing box2d;
// list to hold all the custom shapes (circles, polygons)
ArrayList<CustomShape> polygons = new ArrayList<CustomShape>();
 
// Modes
/*
    NOKINECT
    START
    READY
    PLAY
    END
*/

String _MODE_ = "START";
 
// Timer
int timerStart = 0;
int savedTime;
int totalTime = 1000;
int passedTime;

boolean btnFlag = true;

int _gameTime_ = 20 * 1000; //Total time per session

int _SCORE_;
int _LASTSCORE_;

// Config Time

int TEMPS_JEU = 60; // s
int minStartBallInterval = 200; 
int maxStartBallInterval = 1000; 
 
 
// ----------------------------------------------------
// RUN IN FULLSCREEN
// ----------------------------------------------------

boolean sketchFullScreen() {
  return true;
}

 
void setup() {
  
    println("SET UP");
    
    //size(1280, 720, OPENGL);
    size(displayWidth, displayHeight, OPENGL);
    smooth();
    
    cp5 = new ControlP5(this);

     // Play button
    cp5.addButton("playbtn")
    .setPosition((width/2)-150,(height/2)-50)
    .setSize(300,100)
    .setLabel("--- PLAY ---")
    .getCaptionLabel().align(CENTER,CENTER);
  
    // Scrore textfield  
    PFont font = createFont("arial",20);
    textFont(font);
    
    // setup the timer
    timer = CountdownTimer.getNewCountdownTimer(this).configure(1000, (TEMPS_JEU*1000));
      
    context = new SimpleOpenNI(this);
  
    // initialize SimpleOpenNI object
     
    if (!context.enableScene()) { 
        
        // if context.enableScene() returns false
        // then the Kinect is not working correctly
        // make sure the green light is blinking
        _MODE_ = "NOKINECT";
        println("Kinect not connected!"); 
        exit();
        
    } else {

        // mirror the image to be more intuitive
        context.setMirror(true);
        // calculate the reScale value
        // currently it's rescaled to fill the complete width (cuts of top-bottom)
        // it's also possible to fill the complete height (leaves empty sides)
        reScale = (float) width / kinectWidth;
        // create a smaller blob image for speed and efficiency
        blobs = createImage(kinectWidth/3, kinectHeight/3, RGB);
        // initialize blob detection object to the blob image dimensions
        theBlobDetection = new BlobDetection(blobs.width, blobs.height);
        theBlobDetection.setThreshold(0.3);
        // initialize ToxiclibsSupport object
        gfx = new ToxiclibsSupport(this);
        // setup box2d, create world, set gravity
        box2d = new Box2DProcessing(this);
        box2d.createWorld();
        box2d.setGravity(0, -20);      
    
        savedTime = millis();
    
        _SCORE_ = 0;

    }
}

 
void draw() {
  
    background(230,240,255);

    if( _MODE_ == "READY") {
 
       if(timerStart<6){ // le bouton clignotera 5 fois
          
           passedTime = millis() - savedTime;
          
          if (passedTime > 1000) {
      
            savedTime = millis();
            totalTime = 1000;
            timerStart++;
        
            cp5.controller("playbtn").setLabel("--- READY ---");
        
            if(!btnFlag){
                cp5.controller("playbtn").setColorBackground( color( 255,0,0 ) );
            }else{
                cp5.controller("playbtn").setColorBackground( color( 0,255,0 ) );
            }
            btnFlag = !btnFlag;
         }
      }else{
         // Start of the game
        totalTime = (int)random(minStartBallInterval, maxStartBallInterval);
        cp5.controller("playbtn").hide();        
         _MODE_ = "PLAY";
         if(!timer.isRunning()){
             timer.start();
         }
      }
        
    }else if( _MODE_ == "PLAY" ) {
        // Kinect active -- we are playing
    
        context.update();

        cam = context.sceneImage().get();

        // copy the image into the smaller blob image
        blobs.copy(cam, 0, 0, cam.width, cam.height, 0, 0, blobs.width, blobs.height);
        // blur the blob image
        blobs.filter(BLUR, 1);
        // detect the blobs
        theBlobDetection.computeBlobs(blobs.pixels);
        // initialize a new polygon
        poly = new PolygonBlob();
        // create the polygon from the blobs (custom functionality, see class)
        poly.createPolygon();
        // create the box2d body from the polygon
        poly.createBody();
        // update and draw everything (see method)
        updateAndDrawBox2D();
        // destroy the person's body (important!)
        poly.destroyBody();

    }else if( _MODE_ == "END" ) {
        // End of the game
        killBalls();
        cp5.controller("playbtn").show();
        cp5.controller("playbtn").setLabel("--- PLAY ---");        
         timer.reset();
        minStartBallInterval = 200; 
        maxStartBallInterval = 1000;

        // Total Score
        textSize(40);
        if(_SCORE_>0) _LASTSCORE_ = _SCORE_;
        text("SCORE:"+_LASTSCORE_, (width/2)-100, 150); 
        fill(0);
        
        _SCORE_ = 0;   
        timerCallbackInfo = "";   
        
    }
}
 
void updateAndDrawBox2D() {
  
  // generate Balls
  passedTime = millis() - savedTime;
  if (passedTime > totalTime) {
      
    savedTime = millis();
    totalTime = totalTime = (int)random(minStartBallInterval, maxStartBallInterval);
    
    // Create circle
    int intiXpos = (int)random(25,(kinectWidth-25));
    CustomShape shape = new CustomShape(intiXpos, -50, (int)random(10, 20),BodyType.DYNAMIC);
    polygons.add(shape);
    
    // we go faster and faster
    minStartBallInterval -= 3;
    maxStartBallInterval -= 3;

  }

  // take one step in the box2d physics world
  box2d.step();
 
  // center and reScale from Kinect to custom dimensions
  translate(0, (height-kinectHeight*reScale)/2);
  scale(reScale);

 
  // display the person's polygon  
  noStroke();
  fill(50,50,50);
  gfx.polygon2D(poly);
 
  // display all the shapes (circles, polygons)
  // go backwards to allow removal of shapes
  for (int i=polygons.size()-1; i>=0; i--) {
    CustomShape cs = polygons.get(i);
    // if the shape is off-screen remove it (see class for more info)
    if (cs.done()) {
        println(cs.out);
        if(cs.out == 2){
            _SCORE_++;
        }
        polygons.remove(i);
    // otherwise update (keep shape outside person) and display (circle or polygon)
    } else {
        cs.update();
        cs.display();
    }
    
    // Update Score
    textSize(20);
    fill(0);
    text(_SCORE_, 45, 100); 

    // Update Temps
    textSize(20);
    text(timerCallbackInfo, (kinectWidth/2) - 70, 100); 
    
    
  }
}

public void killBalls() {
   for (int i=polygons.size()-1; i>=0; i--) {
    CustomShape cs = polygons.get(i);
    // if the shape is off-screen remove it (see class for more info)
    cs.kill();
    polygons.remove(i);
   }
}

public void playbtn() {
    println("...PLAY...");
  _MODE_ = "READY";
}

void onTickEvent(int timerId, long timeLeftUntilFinish) {
  timerCallbackInfo = "Time left  " + (int)(timeLeftUntilFinish/1000) + "s";
}

void onFinishEvent(int timerId) {
  timerCallbackInfo = "Time's up!";
  _MODE_ = "END";
}





