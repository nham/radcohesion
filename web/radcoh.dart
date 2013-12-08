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
      gl_FragColor = vec4(0.8, 0.0, 1.0, 1.0);
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
Buffer innerVertexPosBuffer, outerVertexPosBuffer;

void bufferSetup(RenderingContext gl) {
  var x = cos(PI/3);
  var y = sin(PI/3);
  var h = 2 * y;
  var a = [0.0, 0.0, 0.0];
  var b = [2.0,  0.0, 0.0];
  var c = [1.0,  h, 0.0];
  var d = [1.0, 0.0, 0.0]; // between a & b
  var e = [2.0 - x, y, 0.0]; // between b & c
  var f = [x, y, 0.0]; // between c & a
  
  var outer = new List.from(a);
  var inner = new List.from(d);

  outer..addAll(b)
    ..addAll(b)..addAll(c)
    ..addAll(c)..addAll(a);
  
  inner..addAll(e)
    ..addAll(e)..addAll(f)
    ..addAll(f)..addAll(d);
  
  // I think there's a notion of a "current" array buffer, whatever an array buffer is
  // and all buffer operations to array buffers apply only to the current one?
  // so bindBuffer tells us that for all the buffer stuff that follows, we'll be using
  // this one (triangleVertexPositionBuffer)

  // I'm also not sure what STATIC_DRAW is and how it compares to other options!
  
  outerVertexPosBuffer = gl.createBuffer();
  gl.bindBuffer(ARRAY_BUFFER, outerVertexPosBuffer);
  gl.bufferDataTyped(ARRAY_BUFFER, new Float32List.fromList(outer),
      STATIC_DRAW);
  
  
  innerVertexPosBuffer = gl.createBuffer();
  gl.bindBuffer(ARRAY_BUFFER, innerVertexPosBuffer);
  gl.bufferDataTyped(ARRAY_BUFFER, new Float32List.fromList(inner),
      STATIC_DRAW);
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

  mvMatrix.translate([-1.0, -1.0, -4.0]);

  // Here's that bindBuffer() again, as seen in the constructor
  gl.bindBuffer(ARRAY_BUFFER, outerVertexPosBuffer);
  // Set the vertex attribute to the size of each individual element (x,y,z)
  gl.vertexAttribPointer(prog.attributes['aVertexPosition'], 3, FLOAT, false, 0, 0);
  gl.uniformMatrix4fv(prog.uniforms['uPMatrix'], false, pMatrix.buf);
  gl.uniformMatrix4fv(prog.uniforms['uMVMatrix'], false, mvMatrix.buf);
  // Now draw 3 vertices
  gl.drawArrays(LINES, 0, 6);
  
  
  gl.bindBuffer(ARRAY_BUFFER, innerVertexPosBuffer);
  gl.vertexAttribPointer(prog.attributes['aVertexPosition'], 3, FLOAT, false, 0, 0);
  gl.uniformMatrix4fv(prog.uniforms['uPMatrix'], false, pMatrix.buf);
  gl.uniformMatrix4fv(prog.uniforms['uMVMatrix'], false, mvMatrix.buf);
  gl.drawArrays(LINES, 0, 6);
  
  
// Finally, reset the matrix back to what it was before we moved around.
  mvPopMatrix();
}
