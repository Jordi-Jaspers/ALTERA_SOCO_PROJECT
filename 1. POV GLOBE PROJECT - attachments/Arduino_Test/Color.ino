#include "FastLED.h"
#define NUM_LEDS 38
#define DATA_PIN 11
#define CLOCK_PIN 13
unsigned char i;
unsigned char m;
unsigned int wait = 4750;
bool hall = 0;
CRGB leds[NUM_LEDS];

void setup() {
  FastLED.addLeds<APA102, BGR>(leds, NUM_LEDS);
  EICRA = 0;
  EICRA |= (1 << ISC10);
  EIMSK = 0;
  EIMSK |= (1 << INT1);
  sei();
}

ISR (INT1_vect) {
  hall = 1;
}

void loop() {
  if (hall == 1) {
    for (m = 0; m < 5; m++) {
      for (i = 0; i < 38; i++) {
        leds[i] = CRGB::Red;
      }
      FastLED.show();
      delayMicroseconds(wait);

      for (i = 0; i < 38; i++) {
        leds[i] = CRGB::Green;
      }
      FastLED.show();
      delayMicroseconds(wait);

      for (i = 0; i < 38; i++) {
        leds[i] = CRGB::Blue;
      }
      FastLED.show();
      delayMicroseconds(wait);
      hall = 0;
    }
  }
}
