import {Color, Vector2} from "../../js/lib/three.module.js";

import {Thurston} from "../../js/commons/Thurston.js";

import * as geom from "../../js/geometries/hyp/geometry/General.js";
import cube from "../../js/geometries/hyp/subgroups/cube.js";

import {Point, Vector} from "../../js/geometries/hyp/geometry/General.js";
import {PointLight} from "../../js/geometries/hyp/lights/pointLight/PointLight.js";
import {PhongMaterial} from "../../js/commons/material/phong/PhongMaterial.js";
import {Solid, Ball} from "../../js/geometries/hyp/solids/all.js";
import {LocalBallShape, complement} from "../../js/geometries/hyp/shapes/all.js";
import {CheckerboardMaterial} from "../../js/commons/material/checkerboard/CheckerboardMaterial.js";
import {phongWrap} from "../../js/commons/material/phongWrap/PhongWrapMaterial.js";


const thurston = new Thurston(geom, cube, {keyboard: 'fr'});


// lights for the Phong material

//  yellow light
const light0 = new PointLight(
    new Vector(1, 0, 0),
    new Color(1, 1, 0),
);

// cyan light
const light1 = new PointLight(
    new Vector(0, 1, -1),
    new Color(0, 1, 1)
);

// magenta light
const light2 = new PointLight(
    new Vector(-1, -1, 1),
    new Color(1, 0, 1)
);
const lights = [light0, light1, light2];

// Phong shading material
const mat0 = new PhongMaterial({
    color: new Color(1, 0.2, 0.2),
    shininess: 5,
    lights: lights
});

// Complement of a local ball
const ball0 = new LocalBallShape(
    new Point(),
    1.02,
);


const latticeShape = complement(ball0);
const lattice = new Solid(latticeShape, mat0);


const checkerboard = new CheckerboardMaterial(
    new Vector2(Math.PI, 0),
    new Vector2(0, Math.PI),
    new Color(1, 1, 1),
    new Color(0, 0, 1)
)
const mat1 = phongWrap(checkerboard, {lights: lights});


const ball1 = new Ball(
    new Vector(0, 0, -0.5),
    0.2,
    mat1
);

thurston.add(lattice, ball1, light0, light1, light2);
thurston.run();




