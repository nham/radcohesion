library rad_cohesion;

import 'dart:math';
import 'dart:html';
import 'dart:web_gl';
import 'dart:typed_data';

// will replace this with vector_math package eventually. I just want to get something working now
part 'matrix4.dart';

// not sure yet
part 'gl_program.dart';



void main() {
  mvMatrix = new Matrix4()..identity();
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
  
  bufferSetup(gl);
  drawScene(gl, p, canvas.width / canvas.height);
}

RenderingContext glContextSetup(CanvasElement canvas) {
  RenderingContext gl = canvas.getContext3d();
  
  if(gl == null) {
    throw "There's no 3d WebGL thingy. Whatever that is. Barf.";
  }
  
  gl.clearColor(1.0, 0.95, 0.0, 1.0);
  gl.clearDepth(1.0);
  
  // set the GL viewport to the same size as the canvas element so there's no resizing
  gl.viewport(0, 0, canvas.width, canvas.height);
  
  // TODO: figure out what these two do
  gl.enable(DEPTH_TEST);
  gl.disable(BLEND);
  
  return gl;
}


GlProgram programSetup(RenderingContext gl) {
  var fragmentShader = '''
      precision mediump float;

      void main(void) {
      gl_FragColor = vec4(0.85, 0.0, 1.0, 1.0);
      }
      ''';
  
  var vertexShader = '''
      attribute vec3 aVertexPosition;

      uniform mat4 uMVMatrix;
      uniform mat4 uPMatrix;

      void main(void) {
      gl_Position = uPMatrix * uMVMatrix * vec4(aVertexPosition, 1.0);
      }
      ''';
  
  return new GlProgram(gl, fragmentShader, vertexShader, ['aVertexPosition'], ['uMVMatrix', 'uPMatrix']);
}


// the main buffer(s)
Buffer gridPointsPosBuffer, gridPointsIndexBuffer;

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
  
  double x = cos(PI/3);
  double y = sin(PI/3);

  // all vectors referenced from the leftmost point
  // we aren't using Vector3 because it internally uses Float32List, which is a
  // fixed length list, and I'm not sure how to do what I need to do with that.
  
  List<double> u1 = [1.0, 0.0, 0.0]; // from the leftmost going to rightmost
  List<double> u2 = [ -x,   y, 0.0]; // from the rightmost going to topmost
  List<double> u3 = [ -x,  -y, 0.0]; // from the topmost going to leftmost
  
  scaleV (xs, c) => [c * xs[0], c * xs[1], c * xs[2]];

  // we'll return this later
  List<double> a = new List();
  
  for(var i = 0; i < 5; i++) {
    var x = scaleV(u1, i * 1.0);
    a..add(x[0])..add(x[1])..add(x[2]);
  }
  
  List<double> rm = a.sublist(3*4, 3*5);

  for(var i = 1; i < 5; i++) {
    var x = scaleV(u2, i * 1.0);
    a..add(rm[0] + x[0])
     ..add(rm[1] + x[1])
     ..add(rm[2] + x[2]);
  }
  
  List<double> tm = a.sublist(3*8, 3*9); // topmost

  for(var i = 1; i < 4; i++) {
    var x = scaleV(u3, i * 1.0);
    a..add(tm[0] + x[0])
     ..add(tm[1] + x[1])
     ..add(tm[2] + x[2]);
  }
  
  return a;
}

void bufferSetup(RenderingContext gl) {
  var a = genGridPointList();
  
  gridPointsPosBuffer = gl.createBuffer();
  gl.bindBuffer(ARRAY_BUFFER, gridPointsPosBuffer);
  gl.bufferDataTyped(ARRAY_BUFFER, new Float32List.fromList(a), STATIC_DRAW);
  
  // I think there's a notion of a "current" array buffer, whatever an array buffer is
  // and all buffer operations to array buffers apply only to the current one?
  // so bindBuffer tells us that for all the buffer stuff that follows, we'll be using
  // this one (triangleVertexPositionBuffer)

  // I'm also not sure what STATIC_DRAW is and how it compares to other options!
  
  gridPointsIndexBuffer = gl.createBuffer();
  gl.bindBuffer(ELEMENT_ARRAY_BUFFER, gridPointsIndexBuffer);
  
  var gridPointsIndices = [0, 4, 4, 8, 8, 0, // outer vertices of triangle
      1, 7,  1, 11, // lines involving 1
      2, 6,  2, 10, // lines involving 2
      3, 5,  3, 9,  // lines involving 3
      5, 11,
      6, 10,
      7, 9];
  
  // Now send the element array to GL
  gl.bufferDataTyped(ELEMENT_ARRAY_BUFFER, 
      new Uint16List.fromList(gridPointsIndices), STATIC_DRAW);
    
  }

/// Perspective matrix
Matrix4 pMatrix;
/// Model-View matrix.
Matrix4 mvMatrix;
List<Matrix4> mvStack = new List<Matrix4>();

// fat stacks
mvPushMatrix() => mvStack.add(new Matrix4.fromMatrix(mvMatrix));
mvPopMatrix() => mvMatrix = mvStack.removeLast();

void drawScene(RenderingContext gl, GlProgram prog, double aspect) {
  // webgl documentation says "clear buffers to preset values"
  // "glClear sets the bitplane area of the window to values previously selected"
  // TODO: figure out what a bitplane is
  gl.clear(COLOR_BUFFER_BIT | DEPTH_BUFFER_BIT);
  
  // something something field of view is 45 degrees. the last 2 are something to do with depth.
  pMatrix = Matrix4.perspective(45.0, aspect, 0.1, 100.0);
  
  // First stash the current model view matrix before we start moving around.
  mvPushMatrix();

  mvMatrix.translate([-2, -1.5, -6.0]);

  // Here's that bindBuffer() again, as seen in the constructor
  gl.bindBuffer(ARRAY_BUFFER, gridPointsPosBuffer);
  // Set the vertex attribute to the size of each individual element (x,y,z)
  gl.vertexAttribPointer(prog.attributes['aVertexPosition'], 3, FLOAT, false, 0, 0);
 
  
  gl.bindBuffer(ELEMENT_ARRAY_BUFFER, gridPointsIndexBuffer);
  gl.vertexAttribPointer(prog.attributes['aVertexPosition'], 3, FLOAT, false, 0, 0);
  gl.uniformMatrix4fv(prog.uniforms['uPMatrix'], false, pMatrix.buf);
  gl.uniformMatrix4fv(prog.uniforms['uMVMatrix'], false, mvMatrix.buf);
  gl.drawElements(LINES, 24, UNSIGNED_SHORT, 0);

  
// Finally, reset the matrix back to what it was before we moved around.
  mvPopMatrix();
}
