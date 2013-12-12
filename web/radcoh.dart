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
  tetra_mvMatrix = new Matrix4()..identity();
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
  
  gridBufferSetup(gl);
  icosaBufferSetup(gl);
  
  // a closure to keep the last time!
  num lastTime = 0;
  void animate(num now) {
    if (lastTime != 0) {
      var elapsed = now - lastTime;
      triGrid.ang += (60 * elapsed) / 1000.0;
      icosa.ang += (10 * elapsed) / 1000.0;
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
  
  gl.clearColor(0.08, 0.0, 0.0, 1.0);
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
  double sc = s / 4; // used scale u1 through u3 when generating the coords
  
  List<double> u1 = [1.0, 0.0, 0.0]; // from the leftmost going to rightmost
  List<double> u2 = [ -x,   y, 0.0]; // from the rightmost going to topmost
  List<double> u3 = [ -x,  -y, 0.0]; // from the topmost going to leftmost
  
  List<double> v = [-hs, -hs/sl, 0.0]; // vector from the center of the triangle to the leftmost vertex
  
  // we'll return this later
  List<double> a = new List();
  
  for(var i = 0; i < 5; i++) {
    var x = scaleV(u1, i * sc);
    x = addV(x, v);
    a..add(x[0])..add(x[1])..add(x[2]);
  }
  
  List<double> rm = a.sublist(3*4, 3*5);

  for(var i = 1; i < 5; i++) {
    var x = scaleV(u2, i * sc);
    x = addV(x, rm);
    a..add(x[0])..add(x[1])..add(x[2]);
  }
  
  List<double> tm = a.sublist(3*8, 3*9); // topmost

  for(var i = 1; i < 4; i++) {
    var x = scaleV(u3, i * sc);
    x = addV(x, tm);
    a..add(x[0])..add(x[1])..add(x[2]);
  }
  
  return a;
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
  
  
  var gridPointsIndices = [0, 4, 4, 8, 8, 0, // outer vertices of triangle
      1, 7,  1, 11, // lines involving 1
      2, 6,  2, 10, // lines involving 2
      3, 5,  3, 9,  // lines involving 3
      5, 11,
      6, 10,
      7, 9];
  
  gl.bindBuffer(ELEMENT_ARRAY_BUFFER, ibuf);
  gl.bufferDataTyped(ELEMENT_ARRAY_BUFFER, 
      new Uint16List.fromList(gridPointsIndices), STATIC_DRAW);
  

  var colors = [1.0,  1.0,  1.0,  1.0,    // notblack
                1.0,  0.0,  0.0,  1.0,    // red
                1.0,  0.0,  0.0,  1.0,    // red
                1.0,  0.0,  0.0,  1.0,    // red
                1.0,  1.0,  1.0,  1.0,    // notblack
                0.0,  1.0,  0.0,  1.0,    // green
                0.0,  1.0,  0.0,  1.0,    // green
                0.0,  1.0,  0.0,  1.0,    // green
                1.0,  1.0,  1.0,  1.0,    // notblack
                0.0,  0.0,  1.0,  1.0,    // blue
                0.0,  0.0,  1.0,  1.0,    // blue
                0.0,  0.0,  1.0,  1.0     // blue
                ];
  
  print("lens: ${a.length}, ${colors.length}");
  gl.bindBuffer(ARRAY_BUFFER, cbuf);
  gl.bufferData(ARRAY_BUFFER, new Float32List.fromList(colors), STATIC_DRAW);

  
  /*
  gridShapeIndexBuffer = gl.createBuffer();
  gl.bindBuffer(ARRAY_BUFFER, gridShapeIndexBuffer);
  gl.bufferDataTyped(ELEMENT_ARRAY_BUFFER, 
      new Uint16List.fromList([0,4,8]), STATIC_DRAW);
  */
}


void icosaBufferSetup(RenderingContext gl) {
  //TODO refactor so we dont repeat all this? meh, this separate buffer is temporary
  scaleV (xs, c) => [c * xs[0], c * xs[1], c * xs[2]];
  
  addV (u, v) => [u[0] + v[0], u[1] + v[1], u[2] + v[2]];
  
  List<double> a = new List();
  addVtoa (v) => a..add(v[0])..add(v[1])..add(v[2]);
  
  double phi = (1 + sqrt(5))/2;
  List<double> v = [0.0, 1.0, phi];
  
  double s = 3.0;
  
  List<double> top = [ 0.0,  1.0, phi];
  List<double> v1 = [ 0.0, -1.0, phi];
  List<double> v2 = [-phi,  0.0, 1.0];
  List<double> v3 = [-1.0,  phi, 0.0];
  List<double> v4 = [ 1.0,  phi, 0.0];
  List<double> v5 = [ phi,  0.0, 1.0];
 

  addVtoa(top);
  addVtoa(v1);
  addVtoa(v2);
  
  addVtoa(top);
  addVtoa(v2);
  addVtoa(v3);
  
  addVtoa(top);
  addVtoa(v3);
  addVtoa(v4);
  
  addVtoa(top);
  addVtoa(v4);
  addVtoa(v5);
  
  addVtoa(top);
  addVtoa(v5);
  addVtoa(v1);
  
  // invert!
  var bot = scaleV(top, -1.0);
  var w1 = scaleV(v1, -1.0);
  var w2 = scaleV(v2, -1.0);
  var w3 = scaleV(v3, -1.0);
  var w4 = scaleV(v4, -1.0);
  var w5 = scaleV(v5, -1.0);
  
  addVtoa(bot);
  addVtoa(w1);
  addVtoa(w2);
  
  addVtoa(bot);
  addVtoa(w2);
  addVtoa(w3);
  
  addVtoa(bot);
  addVtoa(w3);
  addVtoa(w4);
  
  addVtoa(bot);
  addVtoa(w4);
  addVtoa(w5);
  
  addVtoa(bot);
  addVtoa(w5);
  addVtoa(w1);
  
  addVtoa(v1);
  addVtoa(v2);
  addVtoa(v3);
  
  addVtoa(v1);
  addVtoa(v3);
  addVtoa(v4);
  
  addVtoa(v1);
  addVtoa(v4);
  addVtoa(v5);
  
  addVtoa(v1);
  addVtoa(v5);
  addVtoa(v6);
  
  addVtoa(v1);
  addVtoa(v6);
  addVtoa(v2);
  
  
  print(a);
  
  
  Buffer pbuf, ibuf, cbuf;

  pbuf = gl.createBuffer();
  ibuf = gl.createBuffer();
  cbuf = gl.createBuffer();
  icosa = new Figure(pbuf, ibuf, cbuf, [0.0, -4.0, -18.0], 0.0);

  
  gl.bindBuffer(ARRAY_BUFFER, pbuf);
  gl.bufferDataTyped(ARRAY_BUFFER, new Float32List.fromList(a), STATIC_DRAW);
  
  
  var gridPointsIndices = [ 0,  1,  2,   3,  4,  5,
                            6,  7,  8,   9, 10, 11,
                           12, 13, 14,  15, 16, 17,
                           18, 19, 20,  21, 22, 23,
                           24, 25, 26,  27, 28, 29
                          ];
  
  gl.bindBuffer(ELEMENT_ARRAY_BUFFER, ibuf);
  gl.bufferDataTyped(ELEMENT_ARRAY_BUFFER, 
      new Uint16List.fromList(gridPointsIndices), STATIC_DRAW);
  
  
  var colors = [
                192.0,  62.0,  255.0,  255.0, //purp
                192.0,  62.0,  255.0,  255.0,
                192.0,  62.0,  255.0,  255.0,
                48.0,  186.0,  232.0,  255.0, // blue
                48.0,  186.0,  232.0,  255.0,
                48.0,  186.0,  232.0,  255.0,
                121.0,  255.0,  65.0,  255.0, // green
                121.0,  255.0,  65.0,  255.0,
                121.0,  255.0,  65.0,  255.0,
                232.0,  171.0,  48.0,  255.0, // orangeutan
                232.0,  171.0,  48.0,  255.0, 
                232.0,  171.0,  48.0,  255.0, 
                255.0,  71.0,  117.0,  255.0, // SALMON
                255.0,  71.0,  117.0,  255.0, 
                255.0,  71.0,  117.0,  255.0, 
                
                192.0,  62.0,  255.0,  255 * 0.65, //purp
                192.0,  62.0,  255.0,  255 * 0.65,
                192.0,  62.0,  255.0,  255 * 0.65,
                48.0,  186.0,  232.0,  255 * 0.65, // blue
                48.0,  186.0,  232.0,  255 * 0.65,
                48.0,  186.0,  232.0,  255 * 0.65,
                121.0,  255.0,  65.0,  255 * 0.65, // green
                121.0,  255.0,  65.0,  255 * 0.65,
                121.0,  255.0,  65.0,  255 * 0.65,
                232.0,  171.0,  48.0,  255 * 0.65, // orangeutan
                232.0,  171.0,  48.0,  255 * 0.65, 
                232.0,  171.0,  48.0,  255 * 0.65, 
                255.0,  71.0,  117.0,  255 * 0.65, // SALMON
                255.0,  71.0,  117.0,  255 * 0.65, 
                255.0,  71.0,  117.0,  255 * 0.65
                ];
  
  var new_colors = new List.from(colors.map((x) => x / 255.0));
  print(new_colors);
  
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
Matrix4 tetra_mvMatrix;
List<Matrix4> mvStack = new List<Matrix4>();

// fat stacks
grid_mvPushMatrix() => mvStack.add(new Matrix4.fromMatrix(grid_mvMatrix));
grid_mvPopMatrix() => grid_mvMatrix = mvStack.removeLast();

tetra_mvPushMatrix() => mvStack.add(new Matrix4.fromMatrix(tetra_mvMatrix));
tetra_mvPopMatrix() => tetra_mvMatrix = mvStack.removeLast();


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
  gl.drawElements(LINES, 24, UNSIGNED_SHORT, 0);
  
  grid_mvPopMatrix();
  
  
  // and now we tetra
  tetra_mvPushMatrix();

  tetra_mvMatrix.translate(icosa.pos);
  tetra_mvMatrix.rotateY(radians(icosa.ang)).rotateX(radians(icosa.ang));
  
  gl.bindBuffer(ARRAY_BUFFER, icosa.posBuf);
  // Set the vertex attribute to the size of each individual element (x,y,z)
  gl.vertexAttribPointer(prog.attributes['aVertexPosition'], 3, FLOAT, false, 0, 0);
  
  gl.bindBuffer(ELEMENT_ARRAY_BUFFER, icosa.indexBuf);
  gl.vertexAttribPointer(prog.attributes['aVertexPosition'], 3, FLOAT, false, 0, 0);

  gl.bindBuffer(ARRAY_BUFFER, icosa.colorBuf);
  gl.vertexAttribPointer(prog.attributes['aVertexColor'], 4, FLOAT, false, 0, 0);
  
  
  gl.uniformMatrix4fv(prog.uniforms['uPMatrix'], false, pMatrix.buf);
  gl.uniformMatrix4fv(prog.uniforms['uMVMatrix'], false, tetra_mvMatrix.buf);
  gl.drawElements(TRIANGLES, 30, UNSIGNED_SHORT, 0);

  
// Finally, reset the matrix back to what it was before we moved around.
  tetra_mvPopMatrix();

}
