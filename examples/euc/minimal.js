import * as geom from "../../js/geometries/euc/geometry/General.js";
import torus from "../../js/geometries/euc/subgroups/torus.js";

import {Camera, Renderer, Scene} from "../../js/core/General.js";
import {Mono} from "../../js/commons/stereos/mono/Mono.js";

import {Point} from "../../js/core/geometry/Point.js";
import {Ball} from "../../js/geometries/euc/solids/Ball.js";
import {NormalMaterial} from "../../js/commons/material/normal/NormalMaterial.js";


// initial setup
const camera = new Camera({subgroup: torus});
const scene = new Scene();
const stereo = new Mono();

const renderer = new Renderer(geom, torus, camera, scene, stereo, {
    logarithmicDepthBuffer: true
});
renderer.setPixelRatio(window.devicePixelRatio);
renderer.setSize(window.innerWidth, window.innerHeight);
document.body.appendChild(renderer.domElement);


// defining a material
const mat = new NormalMaterial();
// defining a solid with this material
const ball = new Ball(
    new Point(0, 0, -1),
    0.3,
    mat
);

// adding the solid to the scene
scene.add(ball);

// building there renderer
renderer.build();


// rendering the scene
function animate() {
    renderer.render();
}
renderer.setAnimationLoop(animate);

