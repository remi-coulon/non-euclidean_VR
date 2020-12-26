import * as geom from "../../js/geometries/euc/geometry/General.js";
import torus from "../../js/geometries/euc/subgroups/torus.js";
import trivial from "../../js/commons/subgroups/trivial.js";

import {StereoCamera, VRRenderer, Scene} from "../../js/core/General.js";

import {Point} from "../../js/core/geometry/Point.js";
import {Ball} from "../../js/geometries/euc/solids/Ball.js";
import {NormalMaterial, PhongMaterial} from "../../js/commons/material/all.js";
import {PointLight} from "../../js/geometries/euc/lights/pointLight/PointLight.js";
import {Clock, Color} from "../../js/lib/three.module.js";
import {FlyControls} from "../../js/controls/FlyControls.js";
import {InfoControls} from "../../js/controls/InfoControls.js";



// initial setup
const camera = new StereoCamera({subgroup: torus});
const scene = new Scene();

const renderer = new VRRenderer(geom, trivial, camera, scene, {
    logarithmicDepthBuffer: true
});
renderer.setPixelRatio(window.devicePixelRatio);
renderer.setSize(window.innerWidth, window.innerHeight);
document.body.appendChild(renderer.domElement);


// lights for the Phong material
const light1 = new PointLight(
    new Point(2, 2, -2),
    new Color(1, 1, 0),
)
const light2 = new PointLight(
    new Point(1, -0.8, -1.2),
    new Color(1, 0, 1),
)

const light3 = new PointLight(
    new Point(-1, 0.5, -2),
    new Color(0, 1, 1),
)

const lights = [light1, light2, light3];


// defining a material
const mat = new PhongMaterial({shininess: 10, lights: lights});
// defining solids with this material
const ball1 = new Ball(
    new Point(0, 0, -1),
    0.3,
    mat
);
const ball2 = new Ball(
    new Point(-1, 1, -3),
    0.3,
    mat
);

// adding the solid to the scene
scene.add(ball1, ball2);

// building there renderer
renderer.build();

// event controller on windows resize
function onWindowResize(event) {
    renderer.setSize(window.innerWidth, window.innerHeight);
    camera.aspect = window.innerWidth / window.innerHeight
    camera.updateProjectionMatrix();
}

window.addEventListener("resize", onWindowResize, false);


const clock = new Clock();
const flyControls = new FlyControls(camera, 'fr');
const infoControls = new InfoControls();
infoControls.action = function() {
    console.log(renderer._fragmentBuilder[0].uniforms);
}


// rendering the scene
function animate() {
    const delta = clock.getDelta();
    flyControls.update(delta);
    renderer.render();
}

renderer.setAnimationLoop(animate);
renderer.checkShader();

