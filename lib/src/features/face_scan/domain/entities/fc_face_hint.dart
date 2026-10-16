/// What to tell the user, in priority order: the first that applies wins.
enum FcFaceHint {
  tooDark('Too dark, find more light'),
  noFace('Position your face in the circle'),
  multipleFaces('Only one face please'),
  notCentered('Position your face in the circle'),
  moveCloser('Move closer'),
  moveBack('Move back a little'),
  lookStraight('Look straight at the camera'),
  blink('Blink your eyes'),
  ready('Hold still, ready');

  const FcFaceHint(this.message);

  final String message;
}
