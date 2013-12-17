library rad_cohesion;

import 'dart:math';
import 'dart:html';
import 'dart:web_gl';
import 'dart:typed_data';

// will replace this with vector_math package eventually. I just want to get something working now
part 'matrix4.dart';

// not sure yet
part 'gl_program.dart';


Figure triGrid, icosa;

void main() {
  grid_mvMatrix = new Matrix4()..identity();
  icosa_mvMatrix = new Matrix4()..identity();
  CanvasElement canvas = querySelector("#the-haps");
  
  RenderingContext gl;
  try {
    gl = glContextSetup(canvas);
  } catch(e) {
    print(e);
    return;
  }
  
  var p = programSetup(gl);
  gl.useProgram(p.program);
  
  genGridPointList();
  
  
  gridBufferSetup(gl);
  icosaBufferSetup(gl);
  
  // a closure to keep the last time!
  num lastTime = 0;
  void animate(num now) {
    if (lastTime != 0) {
      var elapsed = now - lastTime;
      triGrid.ang += (60 * elapsed) / 1000.0;
      icosa.ang += (13 * elapsed) / 1000.0;
    }
    
    lastTime = now;
  }
  
  // TODO: read about animationFrame and Futures, which is "the preferred Dart idiom"
  tick (t) {
   window.requestAnimationFrame(tick);
   animate(t);
   drawScene(gl, p, canvas.width / canvas.height);
  }
  
  tick(0);
  
}

RenderingContext glContextSetup(CanvasElement canvas) {
  RenderingContext gl = canvas.getContext3d();
  
  if(gl == null) {
    throw "There's no 3d WebGL thingy. Whatever that is. Barf.";
  }
  
  gl.clearColor(0.5, 0.5, 0.5, 1.0);
  gl.clearDepth(1.0);
  
  // set the GL viewport to the same size as the canvas element so there's no resizing
  gl.viewport(0, 0, canvas.width, canvas.height);
  
  // TODO: figure out what these two do
  gl.enable(DEPTH_TEST);
  gl.disable(BLEND);
  
  return gl;
}


GlProgram programSetup(RenderingContext gl) {
  // Old color: vec4(0.85, 0.0, 1.0, 1.0);
  var fragmentShader = '''
      precision mediump float;
      varying lowp vec4 vColor;

      void main(void) {
      gl_FragColor = vColor;
      }
      ''';
  
  var vertexShader = '''
      attribute vec3 aVertexPosition;
      attribute vec4 aVertexColor;

      uniform mat4 uMVMatrix;
      uniform mat4 uPMatrix;

      varying lowp vec4 vColor;

      void main(void) {
        gl_Position = uPMatrix * uMVMatrix * vec4(aVertexPosition, 1.0);
        vColor = aVertexColor;
      }''';
  
  return new GlProgram(gl, fragmentShader, vertexShader, ['aVertexPosition', 'aVertexColor'], ['uMVMatrix', 'uPMatrix']);
}


List<double> genGridPointList() {
  /*
   *  Please examine this terrible ASCII triangle to become confused. These are the
   *  indices of grid points generated
   * 
   *         8
   *         .
   *     9_ / \ _7
   *   10_ /   \ _6
   *  11_ /     \ _5
   *     /_._._._\
   *    0  1 2 3  4
   */
  
  scaleV (xs, c) => [c * xs[0], c * xs[1], c * xs[2]];
  
  addV (u, v) => [u[0] + v[0], u[1] + v[1], u[2] + v[2]];
  
  double x = cos(PI/3);
  double y = sin(PI/3);
  double sl = tan(PI/3);

  // all vectors referenced from the leftmost point
  // we aren't using Vector3 because it internally uses Float32List, which is a
  // fixed length list, and I'm not sure how to do what I need to do with that.
  
  double s = 3.2;
  double hs = s / 2;
  
  List<double> u1 = [1.0, 0.0, 0.0]; // from the leftmost going to rightmost
  List<double> u2 = [  x,   y, 0.0]; // from the topmost going to leftmost
  
  List<double> v = [-hs, -hs/sl, 0.0]; // vector from the center of the triangle to the leftmost vertex
  
  List<List<List<double>>> a = new List(5);
  
  for(var i = 0; i < 5; i++) {
    var x = scaleV(u2, i * s/4);
    x = addV(x, v);
    a[i] = new List();
    a[i].add(x);
    
    for(var j = 1; j < 5 - i; j++) {
      var y = scaleV(u1, j * s/4);
      a[i].add( addV(x, y) );
    }
  }
  
  List<List<double>> b = new List();
  
  for(var i = 0; i < 4; i++) {
    for(var j = 0; j < 4 - i; j++) {
     b.add(a[i][j]);
     b.add(a[i+1][j]);
    }
    b..add(a[i][4-i]);
  }
  
  List<double> c = new List();
  addVtoc (v) => c..add(v[0])..add(v[1])..add(v[2]);
  for(var i = 7, off = 0; i >= 1; off += i+2, i -= 2) {
    for(var j = 0; j < i; j++) {
      var z = off + j;
      addVtoc(b[z]);
      addVtoc(b[z+1]);
      addVtoc(b[z+2]);
    }
  }
  return c;
}


void gridBufferSetup(RenderingContext gl) {
  // I think there's a notion of a "current" array buffer, whatever an array buffer is
  // and all buffer operations to array buffers apply only to the current one?
  // so bindBuffer tells us that for all the buffer stuff that follows, we'll be using
  // this one (triangleVertexPositionBuffer)

  // I'm also not sure what STATIC_DRAW is and how it compares to other options!

  
  Buffer pbuf, ibuf, cbuf;

  pbuf = gl.createBuffer();
  ibuf = gl.createBuffer();
  cbuf = gl.createBuffer();
  triGrid = new Figure(pbuf, ibuf, cbuf, [0.0, 1.8, -9.0], 0.0);
  
  var a = genGridPointList();  
  
  gl.bindBuffer(ARRAY_BUFFER, pbuf);
  gl.bufferDataTyped(ARRAY_BUFFER, new Float32List.fromList(a), STATIC_DRAW);
  
  
  var gridPointsIndices = [ 0,  1,  2,  3,  4,  5,  6,  7,  8,
                            9, 10, 11, 12, 13, 14, 15, 16, 17,
                           18, 19, 20,

                           21, 22, 23, 24, 25, 26, 27, 28, 29,
                           30, 31, 32, 33, 34, 35,
 
                           36, 37, 38, 39, 40, 41, 42, 43, 44,

                           45, 46, 47];

  
  gl.bindBuffer(ELEMENT_ARRAY_BUFFER, ibuf);
  gl.bufferDataTyped(ELEMENT_ARRAY_BUFFER, 
      new Uint16List.fromList(gridPointsIndices), STATIC_DRAW);
  
  scaleV (xs, c) => [c * xs[0], c * xs[1], c * xs[2], c * xs[3]];
  
  var purp   = [192.0,  62.0,  255.0,  255.0],
      blue   = [48.0,  186.0,  232.0,  255.0],
      green  = [121.0,  255.0,  65.0,  255.0],
      orange = [232.0,  171.0,  48.0,  255.0],
      salmon = [255.0,  71.0,  117.0,  255.0];
  
  
  purp = scaleV(purp, 1/255.0);
  blue = scaleV(blue, 1/255.0);
  green = scaleV(green, 1/255.0);
  orange = scaleV(orange, 1/255.0);
  salmon = scaleV(salmon, 1/255.0);
  
  var colors = new List();
  addColor(v) => colors..add(v[0])..add(v[1])..add(v[2])..add(v[3]);
  
  add3(v) {
    addColor(v);
    addColor(v);
    addColor(v);
  }
  
  add3(purp);
  add3(blue);
  add3(green);
  add3(orange);
  add3(salmon);
  
  add3(purp);
  add3(blue);
  add3(green);
  add3(orange);
  add3(salmon);
  
  add3(purp);
  add3(blue);
  add3(green);
  add3(orange);
  add3(salmon);
  
  add3(purp);
  add3(blue);
  add3(green);
  add3(orange);
  
  gl.bindBuffer(ARRAY_BUFFER, cbuf);
  gl.bufferData(ARRAY_BUFFER, new Float32List.fromList(colors), STATIC_DRAW);

}

List<double> gridifyTriangle(List<double> leftEdge, List<double> botEdge, double s) {
  scaleV (xs, c) => [c * xs[0], c * xs[1], c * xs[2]];
  
  List<List<List<double>>> a = new List(5);
  
  for(var i = 0; i < 5; i++) {
    var x = scaleV(u2, i * s/4);
    x = addV(x, v);
    a[i] = new List();
    a[i].add(x);
    
    for(var j = 1; j < 5 - i; j++) {
      var y = scaleV(u1, j * s/4);
      a[i].add( addV(x, y) );
    }
  }
  
  List<List<double>> b = new List();
  
  for(var i = 0; i < 4; i++) {
    for(var j = 0; j < 4 - i; j++) {
     b.add(a[i][j]);
     b.add(a[i+1][j]);
    }
    b..add(a[i][4-i]);
  }
  
  List<double> c = new List();
  addVtoc (v) => c..add(v[0])..add(v[1])..add(v[2]);
  for(var i = 7, off = 0; i >= 1; off += i+2, i -= 2) {
    for(var j = 0; j < i; j++) {
      var z = off + j;
      addVtoc(b[z]);
      addVtoc(b[z+1]);
      addVtoc(b[z+2]);
    }
  }
  return c;
}


void icosaBufferSetup(RenderingContext gl) {
  //TODO refactor so we dont repeat all this? meh, this separate buffer is temporary
  scaleV (xs, c) => [c * xs[0], c * xs[1], c * xs[2]];
  
  addV (u, v) => [u[0] + v[0], u[1] + v[1], u[2] + v[2]];
  
  List<double> a = new List();
  addVtoa (v) => a..add(v[0])..add(v[1])..add(v[2]);
  
  double phi = (1 + sqrt(5))/2;
  
  double s = 3.0;
  
  List<double> top = [ 0.0,  1.0, phi];

  List<List<double>> v = [[ 0.0, -1.0, phi],
                          [-phi,  0.0, 1.0],
                          [-1.0,  phi, 0.0],
                          [ 1.0,  phi, 0.0],
                          [ phi,  0.0, 1.0]];
  
  var vdiff_top = new List();
  for(var i = 0; i < v.length; i++) {
    vdiff_top.add( addV(top, scaleV(v[i], -1.0)) );
  }
  
  
 
  for(var i = 0; i < 5; i++) {
    addVtoa(top);
    addVtoa(v[i]);
    addVtoa(v[(i+1) % 5]);
  }

  
  // invert!
  var bot = scaleV(top, -1.0);
  //List<List<double>> w = v.map((x) => scaleV(x, -1.0));
  var w = v.map((x) => scaleV(x, -1.0)).toList();

  for(var i = 0; i < 5; i++) {
    addVtoa(bot);
    addVtoa(w[i]);
    addVtoa(w[(i+1) % 5]);
  }

  
  // w3, v1, w4, v2, w5, v3, w1, v4, w2, v5, w3
  
  var z = new List();
  z.add(w[2]);
  z.add(v[0]);
  z.add(w[3]);
  z.add(v[1]);
  z.add(w[4]);
  z.add(v[2]);
  z.add(w[0]);
  z.add(v[3]);
  z.add(w[1]);
  z.add(v[4]);
  z.add(w[2]);
  z.add(v[0]);
  
  for (var i = 0; i < 10; i++) {
    addVtoa(z[i]);
    addVtoa(z[i+1]);
    addVtoa(z[i+2]);
  }
  
  Buffer pbuf, ibuf, cbuf;

  pbuf = gl.createBuffer();
  ibuf = gl.createBuffer();
  cbuf = gl.createBuffer();
  icosa = new Figure(pbuf, ibuf, cbuf, [0.0, -3.0, -16.0], 0.0);

  
  gl.bindBuffer(ARRAY_BUFFER, pbuf);
  gl.bufferDataTyped(ARRAY_BUFFER, new Float32List.fromList(a), STATIC_DRAW);
  
  
  var gridPointsIndices = [ 0,  1,  2,   3,  4,  5,
                            6,  7,  8,   9, 10, 11,
                           12, 13, 14,  15, 16, 17,
                           18, 19, 20,  21, 22, 23,
                           24, 25, 26,  27, 28, 29,
                           
                           30, 31, 32,  33, 34, 35,
                           36, 37, 38,  39, 40, 41, 
                           42, 43, 44,  45, 46, 47, 
                           48, 49, 50,  51, 52, 53,
                           54, 55, 56,  57, 58, 59
                          ];
  
  gl.bindBuffer(ELEMENT_ARRAY_BUFFER, ibuf);
  gl.bufferDataTyped(ELEMENT_ARRAY_BUFFER, 
      new Uint16List.fromList(gridPointsIndices), STATIC_DRAW);
  
  var colors = new List();
  addColor(v) => colors..add(v[0])..add(v[1])..add(v[2])..add(v[3]);
  
  add3(v) {
    addColor(v);
    addColor(v);
    addColor(v);
  }
  
  var purp   = [192.0,  62.0,  255.0,  255.0],
      blue   = [48.0,  186.0,  232.0,  255.0],
      green  = [121.0,  255.0,  65.0,  255.0],
      orange = [232.0,  171.0,  48.0,  255.0],
      salmon = [255.0,  71.0,  117.0,  255.0],
      purp_l   = [192.0,  62.0,  255.0,  255.0 * 0.65],
      blue_l   = [48.0,  186.0,  232.0,  255.0 * 0.65],
      green_l  = [121.0,  255.0,  65.0,  255.0 * 0.65],
      orange_l = [232.0,  171.0,  48.0,  255.0 * 0.65],
      salmon_l = [255.0,  71.0,  117.0,  255.0 * 0.65],
      white = [255.0,  255.0,  255.0,  255.0],
      black = [0.0,  0.0,  0.0,  255.0];
  
  add3(purp);
  add3(blue);
  add3(green);
  add3(orange);
  add3(salmon);
  
  add3(purp_l);
  add3(blue_l);
  add3(green_l);
  add3(orange_l);
  add3(salmon_l);
  
  add3(white);
  add3(black);
  add3(white);
  add3(black);
  add3(white);
  add3(black);
  add3(white);
  add3(black);
  add3(white);
  add3(black);
  
  var new_colors = new List.from(colors.map((x) => x / 255.0));
  
  gl.bindBuffer(ARRAY_BUFFER, cbuf);
  gl.bufferData(ARRAY_BUFFER, new Float32List.fromList(new_colors), STATIC_DRAW);
}


class Figure {
  Buffer posBuf, indexBuf, colorBuf;
  List <double> pos;
  double ang;
  
  Figure(this.posBuf, this.indexBuf, this.colorBuf, this.pos, this.ang);
    
}



/// Perspective matrix
Matrix4 pMatrix;
/// Model-View matrices
Matrix4 grid_mvMatrix;
Matrix4 icosa_mvMatrix;
List<Matrix4> mvStack = new List<Matrix4>();

// fat stacks
grid_mvPushMatrix() => mvStack.add(new Matrix4.fromMatrix(grid_mvMatrix));
grid_mvPopMatrix() => grid_mvMatrix = mvStack.removeLast();

icosa_mvPushMatrix() => mvStack.add(new Matrix4.fromMatrix(icosa_mvMatrix));
icosa_mvPopMatrix() => icosa_mvMatrix = mvStack.removeLast();


void drawScene(RenderingContext gl, GlProgram prog, double aspect) {
  // webgl documentation says "clear buffers to preset values"
  // "glClear sets the bitplane area of the window to values previously selected"
  // TODO: figure out what a bitplane is
  gl.clear(COLOR_BUFFER_BIT | DEPTH_BUFFER_BIT);
  
  // something something field of view is 45 degrees. the last 2 are something to do with depth.
  pMatrix = Matrix4.perspective(45.0, aspect, 0.1, 100.0);
  
  // First stash the current model view matrix before we start moving around.
  grid_mvPushMatrix();

  grid_mvMatrix.translate(triGrid.pos);
  grid_mvMatrix.rotateZ(radians(triGrid.ang));

  gl.bindBuffer(ARRAY_BUFFER, triGrid.posBuf);
  // Set the vertex attribute to the size of each individual element (x,y,z)
  gl.vertexAttribPointer(prog.attributes['aVertexPosition'], 3, FLOAT, false, 0, 0);

  gl.bindBuffer(ELEMENT_ARRAY_BUFFER, triGrid.indexBuf);
  gl.vertexAttribPointer(prog.attributes['aVertexPosition'], 3, FLOAT, false, 0, 0);

  gl.bindBuffer(ARRAY_BUFFER, triGrid.colorBuf);
  gl.vertexAttribPointer(prog.attributes['aVertexColor'], 4, FLOAT, false, 0, 0);
  
  
  gl.uniformMatrix4fv(prog.uniforms['uPMatrix'], false, pMatrix.buf);
  gl.uniformMatrix4fv(prog.uniforms['uMVMatrix'], false, grid_mvMatrix.buf);
  gl.drawElements(TRIANGLES, 48, UNSIGNED_SHORT, 0);
  
  grid_mvPopMatrix();
  
  
  // and now we icosa
  icosa_mvPushMatrix();

  icosa_mvMatrix.translate(icosa.pos);
  icosa_mvMatrix.rotateY(radians(icosa.ang)).rotateX(radians(icosa.ang));
  
  gl.bindBuffer(ARRAY_BUFFER, icosa.posBuf);
  // Set the vertex attribute to the size of each individual element (x,y,z)
  gl.vertexAttribPointer(prog.attributes['aVertexPosition'], 3, FLOAT, false, 0, 0);
  
  gl.bindBuffer(ELEMENT_ARRAY_BUFFER, icosa.indexBuf);
  gl.vertexAttribPointer(prog.attributes['aVertexPosition'], 3, FLOAT, false, 0, 0);

  gl.bindBuffer(ARRAY_BUFFER, icosa.colorBuf);
  gl.vertexAttribPointer(prog.attributes['aVertexColor'], 4, FLOAT, false, 0, 0);
  
  
  gl.uniformMatrix4fv(prog.uniforms['uPMatrix'], false, pMatrix.buf);
  gl.uniformMatrix4fv(prog.uniforms['uMVMatrix'], false, icosa_mvMatrix.buf);
  gl.drawElements(TRIANGLES, 60, UNSIGNED_SHORT, 0);

  
// Finally, reset the matrix back to what it was before we moved around.
  icosa_mvPopMatrix();

}
