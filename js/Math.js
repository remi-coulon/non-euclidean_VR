// console.log(m) prints column by column, which is not what you expect...
// v.applyMatrix4(m) does m*v
// m.multiply(n) does m*n


// length of the step when integrating the geodesic flow with an Euler method
const EULER_STEP = 0.1;


//----------------------------------------------------------------------
//	Object oriented version of the geometry
//----------------------------------------------------------------------

/*

    On the JS part
    - Every point is represented by a THREE.Vector4 object,
      whose coordinates corresponds to the coordinates in the appropriate (projective ?) model
    - Every tangent vector at the origin is represented by a THREE.Vector3 object
      i.e. we identify the tangent space at the origin with R^3.


     The style follow the one of three.js :
     Every operation modifies the current object.
     To make a copy of an object, use the clone method.
     Not sure yet what is the right philosophy for the setters.
 */

THREE.Matrix4.prototype.add = function (matrix) {
    // addition of tow 4x4 matrices
    this.set.apply(this, [].map.call(this.elements, function (c, i) {
        return c + matrix.elements[i];
    }));
    return this;
};

/*
    Representation of an isometry

    The law chosen for Sol is the following
    (a,b,c) * (x,y,z) = (e^c x + a, e^{-c) y + b, z + c)

 */

function Isometry() {
    // In the euclidean geometry an Isometry is just a 4x4 matrix.
    // This may change in the H^2 x R case, where we need an additional translation in the z direction


    // By default the return isometry is the identity
    this.matrix = new THREE.Matrix4();

    this.set = function (data) {
        // set the data
        this.matrix = data[0].clone();
        return this;
    };

    this.makeLeftTranslation = function (x, y, z) {
        // return the left translation by (x,y,z)
        // maybe not very useful for the Euclidean geometry, but definitely needed for Nil or Sol
        this.matrix.set(
            Math.exp(z), 0, 0, x,
            0, Math.exp(-z), 0, y,
            0, 0, 1, z,
            0, 0, 0, 1
        );
        return this;
    };

    this.makeInvLeftTranslation = function (x, y, z) {
        // return the inverse of the left translation by (x,y,z)
        // maybe not very useful for the Euclidean geometry, but definitely needed for Nil or Sol
        this.matrix.set(
            Math.exp(-z), 0, 0, -Math.exp(-z) * x,
            0, Math.exp(z), 0, -Math.exp(z) * y,
            0, 0, 1, -z,
            0, 0, 0, 1
        );
        return this;
    };

    this.premultiply = function (isom) {
        // return the current isometry multiplied on the left by isom, i.e. isom * this
        this.matrix.premultiply(isom.matrix);
        return this;
    };

    this.multiply = function (isom) {
        // return the current isometry multiplied on the left by isom, i.e. this * isom
        this.matrix.multiply(isom.matrix);
        return this;
    };

    this.getInverse = function (isom) {
        // set the current isometry to the inverse of the passed isometry isom,
        this.matrix.getInverse(isom.matrix);
        return this;
    };

    this.equals = function (isom) {
        // test equality of isometries (for debugging purpose mostly)
        return this.matrix.equals(isom.matrix);
    };

    this.clone = function () {
        return new Isometry().set([this.matrix]);
    };
}

/*

    Translating a point by an isometry

 */
THREE.Vector4.prototype.translateBy = function (isom) {
    return this.applyMatrix4(isom.matrix);
};

/*

    Representation of the position of the observer
    A position is given by
    - a `boost` which is an Isometry moving the origin to the point where the observer is
    - a `facing` which determines where the observer is looking at. It is a element of SO(3) encoded as a 4x4 matrix
    More precisely the observer is looking at dL * A * e_z where
    - e_z the tangent vector at the origin in the z-direction
    - A is the matrix defining the facing
    - dL is the differential of the isometry

    TODO.
        the set of position is probably a group
        (a semi-direct projection of Isom(X) by SO(3), where Isom(X) acts on SO(3) by conjugation ?, a direct product ?)
        acting on the underlying Lie group as follows :
        (boost, facing) * g = boost * g * facing
        so that the inverse of a position if (boost^{-1}, facing^{-1})
        - Clarify this point
        - Define the multiplication law on the boost ?

*/

function Position() {

    // By default the return position is the origin (with the "default" facing - negative z-direction ?)
    this.boost = new Isometry();
    this.facing = new THREE.Matrix4();

    this.setBoost = function (boost) {
        this.boost = boost.clone();
        return this;
    };

    this.setFacing = function (facing) {
        this.facing = facing.clone();
        return this;
    };

    this.set = function (boost, facing) {
        this.setBoost(boost);
        this.setFacing(facing);
        return this;
    };

    this.translateBy = function (isom) {
        // translate the position by the given isometry
        this.boost.premultiply(isom);
        return this;
    };

    this.localTranslateBy = function (isom) {
        // if we are at boost of b, our position is b.0. We want to fly forward, and isom
        // tells me how to do this if I were at 0. So I want to apply b * isom * b^{-1} to b * 0, and I get b * isom * 0.
        // In other words, translate boost by the conjugate of isom by boost
        this.boost.multiply(isom);
        this.reduceBoostError();
        return this;
    };

    this.rotateFacingBy = function (rotation) {
        // apply the given matrix (on the left) to the current facing and return the new result
        this.facing.premultiply(rotation);
        this.reduceFacingError();
        return this;
    };

    this.localRotateFacingBy = function (rotation) {
        // apply the given matrix (on the right) to the current facing and return the new result
        this.facing.multiply(rotation);
        this.reduceFacingError();
        return this;
    };

    /*    this.flow = function (v) {
            // move the position following the geodesic flow
            // the geodesic starts at the origin, its tangent vector is v
            // parallel transport the facing along the geodesic

            // in Euclidean geometry, just apply a translation
            // Nothing to do on the facing
            let matrix = new THREE.Matrix4().makeTranslation(v.x, v.y, v.z);
            let isom = new Isometry().set([matrix]);
            return this.translateBy(isom);
        };*/

    this.localFlow = function (v) {
        // move the position following the geodesic flow FROM THE POINT WE ARE AT
        // v is the pull back at the origin of the direction we want to follow

        const dist = v.length();
        const n = dist / EULER_STEP;
        let u = v.clone();
        let field = new THREE.Vector3();
        let pos_aux = ORIGIN.clone().translateBy(this.boost);
        let vec_aux = new THREE.Vector4();
        let mat_aux = new THREE.Matrix4();

        for (let i = 0; i < n; i++) {
            // position of the geodesic at time i*step
            //pos_aux = ORIGIN.clone().translateBy(this.boost);

            // computing the position of the geodesic at time (i+1)*step
            vec_aux = new THREE.Vector4(u.x, u.y, u.z, 0);
            vec_aux.translateBy(this.boost).multiplyScalar(EULER_STEP);
            pos_aux.add(vec_aux);
            // update the boost accordingly
            this.boost.makeLeftTranslation(pos_aux.x, pos_aux.y, pos_aux.z);

            // updating the facing using parallel transport
            mat_aux.set(
                0, 0, -u.x, 0,
                0, 0, u.y, 0,
                u.x, -u.y, 0, 0,
                0, 0, 0, 0
            );
            mat_aux.multiply(this.facing);
            mat_aux.multiplyScalar(-EULER_STEP);
            this.facing.add(mat_aux);
            this.reduceFacingError();
            console.log('boost', this.boost.matrix.elements);
            console.log('facing', this.facing.elements);

            // computing the pull back (at the origin) of the tangent vector at time (i+1)*step
            field.set(
                u.x * u.z,
                -u.y * u.z,
                -u.x * u.x + u.y * u.y
            );
            u.add(field.multiplyScalar(EULER_STEP)).normalize();
        }
        return this;
    };

    this.getInverse = function (position) {
        // set the current position to the position that can bring back the passed position to the origin position
        this.boost.getInverse(position.boost);
        this.facing.getInverse(position.facing);
        this.reduceError();
        return this;

    };

    this.getFwdVector = function () {
        // return the vector moving forward (taking into account the facing)
        return new THREE.Vector3(0, 0, -1).rotateByFacing(this);
    };

    this.getRightVector = function () {
        // return the vector moving right (taking into account the facing)
        return new THREE.Vector3(1, 0, 0).rotateByFacing(this);
    };

    this.getUpVector = function () {
        // return the vector moving up (taking into account the facing)
        return new THREE.Vector3(0, 1, 0).rotateByFacing(this);
    };

    this.reduceBoostError = function () {
        // Nothing to do in Euclidean geometry
        return this;
    };

    this.reduceFacingError = function () {
        // Gram-Schmidt
        let col0 = new THREE.Vector4(1, 0, 0, 0).applyMatrix4(this.facing);
        let col1 = new THREE.Vector4(0, 1, 0, 0).applyMatrix4(this.facing);
        let col2 = new THREE.Vector4(0, 0, 1, 0).applyMatrix4(this.facing);

        col0.normalize();

        let aux10 = col0.clone().multiplyScalar(col0.dot(col1));
        col1.sub(aux10).normalize();

        let aux20 = col0.clone().multiplyScalar(col0.dot(col2));
        let aux21 = col1.clone().multiplyScalar(col1.dot(col2));
        col2.sub(aux20).sub(aux21).normalize();

        this.facing.set(
            col0.x, col1.x, col2.x, 0.,
            col0.y, col1.y, col2.y, 0.,
            col0.z, col1.z, col2.z, 0.,
            0., 0., 0., 1.
        );
        return this;
    };

    this.reduceError = function () {
        this.reduceBoostError();
        this.reduceFacingError();
        return this;
    };

    this.equals = function (position) {
        // test equality of isometries (for debugging purpose mostly)
        return (this.boost.equals(position.boost) && this.facing.equals(position.facing));
    };

    this.clone = function () {
        return new Position().set(this.boost, this.facing);
    }
}

/*

    Rotating a vector

 */

THREE.Vector3.prototype.rotateByFacing = function (position) {
    let aux = new THREE.Vector4(this.x, this.y, this.z, 0).applyMatrix4(position.facing);
    this.set(aux.x, aux.y, aux.z);
    return this;
};


//----------------------------------------------------------------------
//	Geometry constants
//----------------------------------------------------------------------

// The point representing the origin
const ORIGIN = new THREE.Vector4(0, 0, 0, 1);
const cubeHalfWidth = 0.5;

//-----------------------------------------------------------------------------------------------------------------------------
//	Teleporting back to central cell
//-----------------------------------------------------------------------------------------------------------------------------
function geomDist(v) {
    return Math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
}


function fixOutsideCentralCell(position) {
    let cPos = ORIGIN.clone().translateBy(position.boost);
    let bestIndex = -1;

    if (cPos.x > cubeHalfWidth) {
        bestIndex = 1;
    } else if (cPos.x < -cubeHalfWidth) {
        bestIndex = 0;
    } else if (cPos.y > cubeHalfWidth) {
        bestIndex = 3;
    } else if (cPos.y < -cubeHalfWidth) {
        bestIndex = 2;
    } else if (cPos.z > cubeHalfWidth) {
        bestIndex = 5;
    } else if (cPos.z < -cubeHalfWidth) {
        bestIndex = 4;
    }

    if (bestIndex !== -1) {
        position.translateBy(gens[bestIndex]);
        return bestIndex;
    } else {
        return -1;
    }

}

//-----------------------------------------------------------------------------------------------------------------------------
//  Tiling Generators Constructors
//-----------------------------------------------------------------------------------------------------------------------------

function createGenerators() { /// generators for the tiling by cubes.

    const gen0 = new Position().localFlow(new THREE.Vector3(2. * cubeHalfWidth, 0., 0.)).boost;
    const gen1 = new Position().localFlow(new THREE.Vector3(-2. * cubeHalfWidth, 0., 0.)).boost;
    const gen2 = new Position().localFlow(new THREE.Vector3(0., 2. * cubeHalfWidth, 0.)).boost;
    const gen3 = new Position().localFlow(new THREE.Vector3(0., -2. * cubeHalfWidth, 0.)).boost;
    const gen4 = new Position().localFlow(new THREE.Vector3(0., 0., 2. * cubeHalfWidth)).boost;
    const gen5 = new Position().localFlow(new THREE.Vector3(0., 0., -2. * cubeHalfWidth)).boost;

    return [gen0, gen1, gen2, gen3, gen4, gen5];
}

function invGenerators(genArr) {
    return [genArr[1], genArr[0], genArr[3], genArr[2], genArr[5], genArr[4]];
}

//Unpackage boosts into their components (for hyperbolic space, just pull out the matrix which is the first component)
function unpackageMatrix(genArr) {
    let out = [];
    for (let i = 0; i < genArr.length; i++) {
        out.push(genArr[i].matrix);
    }
    return out
}


//-----------------------------------------------------------------------------------------------------------------------------
//	Initialise things
//-----------------------------------------------------------------------------------------------------------------------------

let invGensMatrices; // need lists of things to give to the shader, lists of types of object to unpack for the shader go here


function initGeometry() {
    g_position = new Position();
    g_cellPosition = new Position();
    g_invCellPosition = new Position();
    gens = createGenerators();
    invGens = invGenerators(gens);
    invGensMatrices = unpackageMatrix(invGens);

    let vectorLeft = new THREE.Vector3(-c_ipDist, 0, 0).rotateByFacing(g_position);
    g_leftPosition = new Position().localFlow(vectorLeft);

    let vectorRight = new THREE.Vector3(c_ipDist, 0, 0).rotateByFacing(g_position);
    g_rightPosition = new Position().localFlow(vectorRight);
}


function PointLightObject(v, colorInt) {
    //position is a euclidean Vector4
    let isom = new Position().localFlow(v).boost;
    let lp = ORIGIN.clone().translateBy(isom);
    lightPositions.push(lp);
    lightIntensities.push(colorInt);
}


//DEFINE THE LIGHT COLORS
const lightColor1 = new THREE.Vector4(68 / 256, 197 / 256, 203 / 256, 1);
const lightColor2 = new THREE.Vector4(252 / 256, 227 / 256, 21 / 256, 1);
const lightColor3 = new THREE.Vector4(245 / 256, 61 / 256, 82 / 256, 1);
const lightColor4 = new THREE.Vector4(256 / 256, 142 / 256, 226 / 256, 1);


function initObjects() {
    PointLightObject(new THREE.Vector3(1., 0, 0), lightColor1);
    PointLightObject(new THREE.Vector3(0, 1., 0), lightColor2);
    PointLightObject(new THREE.Vector3(0, 0, 1.), lightColor3);
    PointLightObject(new THREE.Vector3(-1., -1., -1.), lightColor4);
    globalObjectPosition = new Position().localFlow(new THREE.Vector3(0, 0, -1.));
}

//-------------------------------------------------------
// Set up shader 
//-------------------------------------------------------
// We must unpackage the boost data here for sending to the shader.

function setupMaterial(fShader) {

    g_material = new THREE.ShaderMaterial({
        uniforms: {

            isStereo: {
                type: "bool",
                value: g_vr
            },
            screenResolution: {
                type: "v2",
                value: g_screenResolution
            },
            lightIntensities: {
                type: "v4",
                value: lightIntensities
            },
            //--- geometry dependent stuff here ---//
            //--- lists of stuff that goes into each invGenerator
            invGenerators: {
                type: "m4",
                value: invGensMatrices
            },
            //--- end of invGen stuff
            currentBoostMat: {
                type: "m4",
                value: g_position.boost.matrix
            },
            leftBoostMat: {
                type: "m4",
                value: g_leftPosition.boost.matrix
            },
            rightBoostMat: {
                type: "m4",
                value: g_rightPosition.boost.matrix
            },
            //currentBoost is an array
            facing: {
                type: "m4",
                value: g_position.facing
            },
            leftFacing: {
                type: "m4",
                value: g_leftPosition.facing
            },
            rightFacing: {
                type: "m4",
                value: g_rightPosition.facing
            },
            cellBoostMat: {
                type: "m4",
                value: g_cellPosition.boost.matrix
            },
            invCellBoostMat: {
                type: "m4",
                value: g_invCellPosition.boost.matrix
            },
            cellFacing: {
                type: "m4",
                value: g_cellPosition.facing
            },
            invCellFacing: {
                type: "m4",
                value: g_invCellPosition.facing
            },
            lightPositions: {
                type: "v4",
                value: lightPositions
            },
            globalObjectBoostMat: {
                type: "m4",
                value: globalObjectPosition.boost.matrix
            },
            globalSphereRad: {
                type: "f",
                value: 0.2
            },
            earthCubeTex: { //earth texture to global object
                type: "",
                value: new THREE.CubeTextureLoader().setPath('images/cubemap512/')
                    .load([ //Cubemap derived from http://www.humus.name/index.php?page=Textures&start=120
                        'posx.jpg',
                        'negx.jpg',
                        'posy.jpg',
                        'negy.jpg',
                        'posz.jpg',
                        'negz.jpg'
                    ])
            }
        },

        vertexShader: document.getElementById('vertexShader').textContent,
        fragmentShader: fShader,
        transparent: true
    });
}


function updateMaterial() {
    /*
        It seems that to be properly passed to the shader,
        a uniform `foo` cannot be updated on the js side by a statement of the form
        > foo = new_value_of_foo
        One has to use a statement that alter the object `foo` e.g.
        > foo. attribute = new_value of the attribute
        (Maybe some subtleties in the pointer management ?)

        This can be an issue when passing float to the shader
        (Remark: is foo += 1 totally equivalent to foo = foo + 1 in this context?)
        This method is called each time `animate` is used (at every frame ?) and can be used to update uniforms
        > g_material.uniforms.foo.value = new_value_of_foo

     */

    //g_material.uniform.foo.value = 0;


}
