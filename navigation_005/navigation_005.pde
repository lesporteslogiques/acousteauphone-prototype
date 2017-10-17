/*
 * Récupération des données venues du cloud et de l'interface physique 
 * Ocean Hackathon, Brest, 14 octobre 2017
 * pierre <> les porteslogiques.net
 * processing 3.2.1 / zibu / debian 7 wheezy 
 * bibliothèques : controlP5 2.2.6, oscP5 0.9.9
 */


import controlP5.*;

import oscP5.*;
import netP5.*;

import processing.serial.*;

Serial myPort;  // Create object from Serial class
int val;      // Data received from the serial port
int pot1, pot2, pot3, pot4, pot5, pot6;
int bouton1, bouton2, bouton3;

PVector[] positions = new PVector[500]; // 500 dernières positions parcourues

float vitesse = 0.09;              // deplacement 
float direction = 90;               // angle du deplacement
float deviation = 20;               // amplitude de variation de l'angle (-deviation, deviation)

PFont police;

OscP5 oscP5;
NetAddress myRemoteLocation;
String oscP5event = "oscEvent";

ControlP5 cp5;
Knob k_rayon;
Knob k_vitesse;
Knob k_fxmod;
Knob k_fymod;
Knob k_deviation;
Knob k_scalesignal;
Knob k_phasorfreq;
Knob k_filterq;

// paramètres du terrain ***********************************************
int cols, rows;
int scl = 30;
int w = 600;
int h = 600;
float flying = 0;
float fly_x, fly_y;
float fxmod = 0.4;
float fymod = 0.1;
float[][] terrain;

// paramètres de l'onde
int samples = 360;
float[] onde = new float[samples];
float rayon = 30;

// récupérer les valeurs
PGraphics pixel_zone;
//PGraphics pixel_zone_x4;

void setup() {
  size(1000, 400, P3D);
  background(0);
  police = loadFont("DejaVuSansCondensed-Bold-64.vlw");
  textFont(police, 48);
  
  // ATTENTION à bien utiliser le port adapté
  printArray(Serial.list());
  String portName = Serial.list()[7];
  myPort = new Serial(this, portName, 9600);
  myPort.bufferUntil('\n'); 
  
  cp5 = new ControlP5(this);
  k_rayon = cp5.addKnob("rayon")
               .setRange(0.1,60)
               .setValue(rayon)
               .setPosition(400,5)
               .setRadius(24)
               .setDragDirection(Knob.HORIZONTAL);
               
  k_vitesse = cp5.addKnob("vitesse")
               .setRange(0.01,1)
               .setValue(vitesse)
               .setPosition(470,5)
               .setRadius(24)
               .setDragDirection(Knob.HORIZONTAL);
               
  k_fxmod = cp5.addKnob("fxmod")
               .setRange(0.001,0.1)
               .setValue(fxmod)
               .setPosition(540,5)
               .setRadius(24)
               .setDragDirection(Knob.HORIZONTAL); 
               
  k_fymod = cp5.addKnob("fymod")
               .setRange(0.001,0.1)
               .setValue(fymod)
               .setPosition(610,10)
               .setRadius(24)
               .setDragDirection(Knob.HORIZONTAL); 
  
  k_deviation = cp5.addKnob("deviation")
               .setRange(0,180)
               .setValue(deviation)
               .setPosition(680,10)
               .setRadius(24)
               .setDragDirection(Knob.HORIZONTAL);             
  
  k_scalesignal = cp5.addKnob("scalesignal")
               .setRange(0.1,2)
               .setValue(1)
               .setPosition(400,85)
               .setRadius(24)
               .setDragDirection(Knob.HORIZONTAL); 
 
  k_phasorfreq = cp5.addKnob("phasorfreq")
               .setRange(0.5,240)
               .setValue(20)
               .setPosition(470,85)
               .setRadius(24)
               .setDragDirection(Knob.HORIZONTAL); 
  
  k_filterq = cp5.addKnob("filterq")
               .setRange(8, 400)
               .setValue(40)
               .setPosition(540,85)
               .setRadius(24)
               .setDragDirection(Knob.HORIZONTAL);
               
  // Initialisation des positions **************************************
  initialiserPositions();
  
  // Définition des paramètes OSC **************************************
  oscP5 = new OscP5(this,8000);
  myRemoteLocation = new NetAddress("127.0.0.1",12000);
  
  // Définition des variables pour l'affichage du terrain **************
  cols = w / scl;
  rows = h/ scl;
  terrain = new float[cols][rows];
  
  // création des images pour récupérer les valeurs
  pixel_zone = createGraphics(cols, rows);
  //pixel_zone_x4 = createGraphics(cols * 4, rows * 4);
}

void draw() {
  
  background(0);
  strokeWeight(1);
  
  // Affichage terrain et orbite ************************************
  //flying -= 0.01;

  //float yoff = flying;
  float fy = fly_y;
  float fx = fly_x;
  for (int y = 0; y < rows; y++) {
    //float xoff = 0;
    for (int x = 0; x < cols; x++) {
      terrain[x][y] = map(noise(fx, fy), 0, 1, -40, 40);
      fx += fxmod;
    }
    fy += fymod;
  }
  
  // création des images du terrain
  pixel_zone.beginDraw();
  pixel_zone.background(0);
  for (int y = 0; y < rows; y++) {
    for (int x = 0; x < cols; x++) {
      float cc = map(terrain[x][y], -40, 40, 0, 255); 
      pixel_zone.stroke(cc, cc, cc, 255);
      pixel_zone.point(x, y);
    }
  }
  pixel_zone.endDraw();

  stroke(255);
  noFill();
  pushMatrix();
  translate(width/2, height/2);
  rotateX(PI/3);
  translate(-w/2, -h/2 + 30);
  for (int y = 0; y < rows-1; y++) {
    beginShape(TRIANGLE_STRIP);
    for (int x = 0; x < cols; x++) {
      vertex(x*scl, y*scl, terrain[x][y]);
      vertex(x*scl, (y+1)*scl, terrain[x][y+1]);
    }
    endShape();
  }
  
  ellipseMode(CENTER);
  noStroke();
  fill(255, 0, 0, 100);
  ellipse(w/2, h/2, rayon * 5, rayon * 5);
  popMatrix();
  
  // Calcul et affichage du trajet ********************************

  direction += random(-deviation, deviation);
  float x = positions[0].x + vitesse * cos(radians(direction));
  float y = positions[0].y + vitesse * sin(radians(direction));
  decalerPositions();
  positions[0].set(x, y);
  
  fly_x = fly_x + vitesse * cos(radians(direction));
  fly_y = fly_y + vitesse * sin(radians(direction));

  stroke(255, 0, 0);
  fill(255, 0, 0);
  strokeWeight(6);
  point(x, y);

  for (int i = positions.length - 1; i > 0; i--) {
    line(positions[i].x, positions[i].y, positions[i-1].x, positions[i-1].y);
  }
  
  // Affichage des coordonnées ************************************

  fill(255);
  text("X : " + positions[0].x, 20, 60); 
  text("Y : " + positions[0].y, 20, 120); 
  
  // Affichage de la "height map"

  float pzw = pixel_zone.width * 4;
  float pzh = pixel_zone.height * 4;
  image(pixel_zone, width - pzw, 0, pzw , pzh);
  
  // Construire l'onde
  for (int i = 0; i < samples; i++) {
    float inc = 360 / samples;
    float ox = width - (pzw / 2) + rayon * cos(radians(i * inc));
    float oy = (pzh / 2) + rayon * sin(radians(i * inc));
    color ccc = get(int(ox), int(oy));
    onde[i] = brightness(ccc) / 255;

    //println(i + " " + ox + " " + oy + " " + onde[i]);
  }
  
  // envoyer les données OSC
  for (int i = 0; i < samples; i++) {
    envoyerOrbite(i, onde[i]);
  }
  
  // Tracer le disque sur la height map
  ellipseMode(CENTER);
  noStroke();
  fill(255, 0, 0, 100);
  ellipse(width - (pzw / 2), pzh / 2, rayon, rayon);
  
  //noLoop();
}

void initialiserPositions() {
  for (int i = positions.length - 1; i >= 0; i--) {
    positions[i] = new PVector(width / 2, height / 2);
  }
}

void decalerPositions() {
  for (int i = positions.length - 1; i > 0; i--) {
    positions[i] = new PVector(positions[i-1].x, positions[i-1].y);
  }
}

void keyPressed() {
  if (key == 'r' || key == 'R') { // Reset
    background(0);
    initialiserPositions();
  }
  if (key == 'o') {
    for (int i = 0; i < samples; i++) {
      //println(i + " " + onde[i]);
      envoyerOrbite(i, onde[i]);
    }
  }
}

void rayon(float theValue) {
  rayon = theValue;
}
void vitesse(float theValue) {
  vitesse = theValue;
}
void fxmod(float theValue) {
  fxmod = theValue;
}
void fymod(float theValue) {
  fymod = theValue;
}
void deviation(float theValue) {
  deviation = theValue;
}
void scalesignal(float theValue) {
  OscMessage message = new OscMessage("/scalesignal");
  message.add(theValue);
  oscP5.send(message, myRemoteLocation);
}
void phasorfreq(float theValue) {
  OscMessage message = new OscMessage("/phasorfreq");
  message.add(theValue);
  oscP5.send(message, myRemoteLocation);
}
void filterq(float theValue) {
  OscMessage message = new OscMessage("/filterq");
  message.add(theValue);
  oscP5.send(message, myRemoteLocation);
}

void envoyerOrbite(float index, float valeur) {
  OscMessage message = new OscMessage("/orbite");
  message.add(index);
  message.add(valeur);
  oscP5.send(message, myRemoteLocation);
}

void serialEvent (Serial myPort) {

  while (myPort.available() > 0) {

    String inBuffer = myPort.readStringUntil('\n');
    
    //println(inBuffer);
    
    if (inBuffer != null) {
      if (inBuffer.substring(0, 1).equals("{")) {
        
        JSONObject json = parseJSONObject(inBuffer);
        
        if (json == null) {
          //println("JSONObject could not be parsed");
        } else {
          //println("json ok");
          pot1    = json.getInt("pot1");
          pot2    = json.getInt("pot2");
          pot3    = json.getInt("pot3");
          pot4    = json.getInt("pot4");
          pot5    = json.getInt("pot5");
          pot6    = json.getInt("pot6");
          bouton1 = json.getInt("bouton1"); 
          bouton2 = json.getInt("bouton2"); 
          bouton3 = json.getInt("bouton3"); 
          /*
          print("pot 1 : " + pot1 + ", ");
          print("pot 2 : " + pot2 + ", ");
          print("pot 3 : " + pot3 + ", ");
          print("pot 4 : " + pot4 + ", ");
          print("pot 5 : " + pot5 + ", ");
          print("pot 6 : " + pot6 + ", ");
          print("bouton 1 : " + bouton1 + ", ");
          print("bouton 2 : " + bouton2 + ", ");
          println("bouton 3 : " + bouton3 + ", ");
          */
          float p1temp = map(pot1, 0, 1023, 0.1, 60);
          if (k_rayon.getValue() != p1temp) k_rayon.setValue(p1temp);
          float p2temp = map(pot2, 0, 1023, 0.01, 1);
          if (k_vitesse.getValue() != p2temp) k_vitesse.setValue(p2temp);
          float p3temp = map(pot3, 0, 1023, 0, 180);
          if (k_deviation.getValue() != p3temp) k_deviation.setValue(p3temp);
          float p4temp = map(pot4, 0, 1023, 0.1, 2);
          if (k_scalesignal.getValue() != p4temp) {
            k_scalesignal.setValue(p4temp);
            scalesignal(p4temp);  
          }
          float p5temp = map(pot5, 0, 1023, 0.5, 240);
          if (k_phasorfreq.getValue() != p5temp) {
            k_phasorfreq.setValue(p5temp);
            phasorfreq(p5temp);  
          }
          float p6temp = map(pot6, 0, 1023, 8, 400);
          if (k_filterq.getValue() != p6temp) {
            k_filterq.setValue(p6temp);
            filterq(p6temp);  
          }
        }
      } else {
      }     
    }
  }
}