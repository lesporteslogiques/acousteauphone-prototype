/*
 * Interface physique de contrôle
 * 6 potentiomètres, 3 boutons
 * les données sont envoyées en JSON à processing
 * Ocean Hackathon, Brest, 14 octobre 2017
 * pierre <> les porteslogiques.net
 * arduino 1.8.2 / zibu / debian 7 wheezy 
 */

int pot1 = A0; 
int pot2 = A5;
int pot3 = A6;
int pot4 = A1;
int pot5 = A4;
int pot6 = A7;

int val1, val2, val3, val4, val5, val6;    
int b1, b2, b3;

void setup()
{
  Serial.begin(9600);
  pinMode(6, INPUT);
  pinMode(5, INPUT);
  pinMode(4, INPUT);
}

void loop()
{
  val1 = analogRead(pot1);
  delay(10);
  val2 = analogRead(pot2);
  delay(10);
  val3 = analogRead(pot3);
  delay(10);
  val4 = analogRead(pot4);
  delay(10);
  val5 = analogRead(pot5);
  delay(10);
  val6 = analogRead(pot6);
  delay(10);

  if (digitalRead(6) == 1) { 
    b1 = 1;
  } else {
    b1 = 0;
  }
  if (digitalRead(5) == 1) { 
    b2 = 1;
  } else {
    b2 = 0;
  }
  if (digitalRead(4) == 1) { 
    b3 = 1;
  } else {
    b3 = 0;
  }
  
  String json;

  //json = "{\"controle\":{\"pot1\":";
  json = "{\"pot1\":";
  json = json + val1;
  json = json + ",\"pot2\":";
  json = json + val2;
  json = json + ",\"pot3\":";
  json = json + val3;
  json = json + ",\"pot4\":";
  json = json + val4;
  json = json + ",\"pot5\":";
  json = json + val5;
  json = json + ",\"pot6\":";
  json = json + val6;
  json = json + ",\"bouton1\":";
  json = json + b1;
  json = json + ",\"bouton2\":";
  json = json + b2;
  json = json + ",\"bouton3\":";
  json = json + b3;
  json = json + "}";

  Serial.println(json);
}
