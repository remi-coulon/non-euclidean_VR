/**
 * @module Thurston
 *
 * @description
 * Module used to define and render a scene in one of the eight Thurston geometries.
 */

import {
    WebGLRenderer,
    Scene,
    OrthographicCamera,
    PlaneBufferGeometry,
    ShaderMaterial,
    Mesh,
    Vector2,
    Clock,
    Quaternion,
    Matrix4
} from "./lib/three.module.js";

import {
    mustache
} from "./lib/mustache.mjs";

import {
    GUI
} from "./lib/dat.gui.module.js";

import {
    SHADER_PASS,
    StaticProp,
    DynamicProp,
    isShaderCst,
    isShaderUni,
    addShaderCst,
    addShaderUni
} from "./property.js";

/**
 * Code for movement of the observer.
 * @const
 */
const ACTION_CODES = {
    TRANSLATE_X_POS: 0,
    TRANSLATE_X_NEG: 1,
    TRANSLATE_Z_POS: 2,
    TRANSLATE_Y_POS: 3,
    TRANSLATE_Y_NEG: 4,
    TRANSLATE_Z_NEG: 5,
    ROTATE_X_POS: 6,
    ROTATE_X_NEG: 7,
    ROTATE_Y_POS: 8,
    ROTATE_Y_NEG: 9,
    ROTATE_Z_POS: 10,
    ROTATE_Z_NEG: 11
}


/**
 * Keyboard commands.
 * Each main entry correspond to a keyboard type (American, French, etc).
 * @const
 */
const KEYBOARD_BINDINGS = {
    'us': {
        65: ACTION_CODES.ROTATE_Y_POS, // a
        68: ACTION_CODES.ROTATE_Y_NEG, // d
        87: ACTION_CODES.ROTATE_X_POS,// w
        83: ACTION_CODES.ROTATE_X_NEG, // s
        81: ACTION_CODES.ROTATE_Z_POS, // q
        69: ACTION_CODES.ROTATE_Z_NEG, // e
        38: ACTION_CODES.TRANSLATE_Z_NEG, // up
        40: ACTION_CODES.TRANSLATE_Z_POS,// down
        37: ACTION_CODES.TRANSLATE_X_NEG, // left
        39: ACTION_CODES.TRANSLATE_X_POS,// right
        222: ACTION_CODES.TRANSLATE_Y_POS,// single quote
        191: ACTION_CODES.TRANSLATE_Y_NEG,// fwd slash
    },
    'fr': {
        81: ACTION_CODES.ROTATE_Y_POS, // q
        68: ACTION_CODES.ROTATE_Y_NEG,// d
        90: ACTION_CODES.ROTATE_X_POS, // z
        83: ACTION_CODES.ROTATE_X_NEG, // s
        65: ACTION_CODES.ROTATE_Z_POS,// a
        69: ACTION_CODES.ROTATE_Z_NEG,// e
        38: ACTION_CODES.TRANSLATE_Z_NEG,// up
        40: ACTION_CODES.TRANSLATE_Z_POS,// down
        37: ACTION_CODES.TRANSLATE_X_NEG, // left
        39: ACTION_CODES.TRANSLATE_X_POS, // right
        165: ACTION_CODES.TRANSLATE_Y_POS, // ù
        61: ACTION_CODES.TRANSLATE_Y_NEG, // =
    }
};


/**
 * @class
 *
 * @classdesc
 * Class used to create a scene in the specified geometry
 *
 * @property {Object} geometry - the underlying geometry (in the form of an imported module)
 * @property lattice - the lattice used for local scenes
 * @property {Object} options - the general options of the scene
 * @property {Object} solids - the list of solids in the scene
 * @property {Object} lights - the list of lights in the scene
 * @property {Object} _uniforms - the list of uniform passed to the shader
 * @property {Vector2} _resolution - the resolution of the windows
 * @property {Position} position - position of the observer
 * @property {Position} leftPosition - position of the left eye (relative to the observer's position)
 * @property {Position} rightPosition - position of the right eye (relative to the observer's position)
 * @property {Isometry} cellBoost - isometry moving you in the correct cell
 * @property {Isometry} invCellBoost - isometry moving you back from the correct cell
 *
 * @todo Decide how to represent a lattice
 */
class Thurston {
    /**
     * Create an instance dedicated to build a scene in the prescribed geometry.
     * @param {Object} geom - a module handing the relevant geometry
     * @param {Object} options - a list of options. See defaultOptions for the list of available options.
     * @todo Check if the geometry satisfies all the requirement?
     */
    constructor(geom, options = {}) {
        // setup the geometry (as a module)
        this.geom = geom;

        const defaultOptions = Thurston.defaultOptions();
        let optionValue;
        for (const property in defaultOptions) {
            if (defaultOptions.hasOwnProperty(property)) {
                if (options.hasOwnProperty(property)) {
                    optionValue = options[property];
                } else {
                    optionValue = defaultOptions[property].value;
                }
                switch (defaultOptions[property].shaderPass) {
                    case SHADER_PASS.CONSTANT:
                        this[property] = addShaderCst(optionValue, defaultOptions[property].shaderType);
                        break;
                    case SHADER_PASS.UNIFORM:
                        this[property] = addShaderUni(optionValue, defaultOptions[property].shaderType);
                        break;
                    default:
                        this[property] = optionValue;
                }
            }
        }

        // setup the initial positions
        this.position = new this.geom.Position();
        this.leftPosition = new this.geom.Position();
        this.rightPosition = new this.geom.Position();
        this.cellBoost = new this.geom.Isometry();
        this.invCellBoost = new this.geom.Isometry();

        // init the list of items in the scene
        this._solids = {};
        this._lights = {};
        // first available id of an item (to be incremented when adding items)
        this._id = 0;

        // define all the remaining properties
        // (maybe not needed in JS, but good practice I guess)
        // some of these properties are setup via an asynchronous procedure, which cannot take place in a constructor
        this.gui = undefined;
        this.guiInfo = undefined;
        this.stats = undefined;
        this.uniforms = undefined;
        this.resolution = addShaderUni(new Vector2(), 'vec2');
        this._renderer = undefined;
        this._scene = undefined;
        this._camera = undefined;
        this.stereo = addShaderUni(false, 'bool');

        // setup the controls for the keyboard
        // fix the default keyboard binding
        // its value can be changed in the UI
        this._keyboardBinding = KEYBOARD_BINDINGS[this.keyboard];
        // setup the controls for keyboard action
        // used to handle an active tag, in case the user hold a key down.
        this._keyboardControls = {};
        for (const action of Object.values(ACTION_CODES)) {
            this._keyboardControls[action] = {active: false};
        }
        // setup the translation/rotation "direction" used when the user moves via the keyboard
        this._keyboardDirs = {
            translation: new this.geom.Vector(),
            rotation: new this.geom.Vector(),
        };
        this._clockPosition = new Clock();
    }


    /**
     * Return the list of all available options, with there default value.
     * Only those options are accepted in the constructor.
     * Each options that is not passed to the constructor is set to its default value.
     *
     * The format for each default option should have the form
     * propertyName : {
     *      value: default value of the property,
     *      shader: undefined || { shaderPass : int, shaderType : string }
     * }
     *
     * @return {Object} the default values of the available options.
     */
    static defaultOptions() {
        return {
            keyboard: {value: 'us', shaderPass: SHADER_PASS.NONE},
            speedTranslation: {value: 0.2, shaderPass: SHADER_PASS.NONE},
            speedRotation: {value: 0.4, shaderPass: SHADER_PASS.NONE},
            MAX_DIRS: {value: 3, shaderPass: SHADER_PASS.CONSTANT, shaderType: 'int'},
            maxMarchingSteps: {value: 50, shaderPass: SHADER_PASS.UNIFORM, shaderType: 'int'},
            minDist: {value: 0, shaderPass: SHADER_PASS.UNIFORM, shaderType: 'float'},
            maxDist: {value: 30, shaderPass: SHADER_PASS.UNIFORM, shaderType: 'float'},
            marchingThreshold: {value: 0.001, shaderPass: SHADER_PASS.CONSTANT, shaderType: 'float'},
            fov: {value: 90, shaderPass: SHADER_PASS.UNIFORM, shaderType: 'float'},
        }
    }

    get listSolids() {
        return Object.values(this._solids);
    }

    get listLights() {
        return Object.values(this._lights);
    }

    /**
     * Setup the lattice used for the local scene.
     * @param data - some data describing the lattice
     * @return {Thurston} the current Thurston object
     *
     * @todo Decide how the lattice should be defined
     */
    setLattice(data) {
        return this;
    }

    /**
     * Set the given options.
     * @param {Object} options - a list of option
     * @return {Thurston} the current Thurston object
     */
    setOptions(options) {
        for (const key in options) {
            if (options.hasOwnProperty(key)) {
                this.setOption(key, options[key]);
            }
        }
        return this;
    }

    /**
     * Set the given option.
     * @param {string} key - key of the option
     * @param  value - the value of the option
     * @return {Thurston} the current Thurston object
     */
    setOption(key, value) {
        return this;
    }

    /**
     * Adding an item to the scene.
     * @param{Item} item - the item to add
     * @return {Thurston} the current Thurston object
     */
    addItem(item) {
        item.id = this._id;
        if (item.isSolid()) {
            this._solids[this._id] = item;
        }
        if (item.isLight()) {
            this._lights[this._id] = item;
        }
        this._id = this._id + 1;

        return this;
    }

    /**
     * Adding a list of item to the scene.
     * @param{Array} items - the list of items to add
     * @return {Thurston} the current Thurston object
     */
    addItems(items) {
        for (const item of items) {
            this.addItem(item);
        }
        return this
    }


    /**
     * add the name of the geometry to the title of the page
     */
    appendTitle() {
        const title = document.querySelector('title');
        title.append(' - ' + this.geom.name);
        return this;
    }

    /**
     * Serialize all the positions and boost in a form that can be passed to the shader
     * @return {array} the output in an array with three entries:
     * - a list of 5 Matrix4 (the part A of the isometries position, left/right position, cell and invCell).
     * - a list of 5 floating numbers (the part B of the isometries position, left/right position, cell and invCell).
     * - a list of 3 Matrix4 (the facing, left and right facings).
     */
    serialize() {
        const rawA = [];
        const rawB = [];
        const facings = [];
        let i = 0;
        let raw;
        const data = [
            this.position,
            this.leftPosition,
            this.rightPosition,
            this.cellBoost,
            this.invCellBoost
        ]
        for (const pos of data) {
            raw = pos.serialize();
            rawA[i] = raw[0];
            rawB[i] = raw[1];
            if (i < 3) {
                facings[i] = raw[2];
            }
            i = i + 1;
        }
        return [rawA, rawB, facings];
    }

    /**
     * Setup the uniforms which are passed to the shader
     */
    setupUniforms() {
        const rawData = this.serialize();
        this.uniforms = {
            boostRawA: {
                type: "mat4",
                value: rawData[0][0]
            },
            leftBoostRawA: {
                type: "mat4",
                value: rawData[0][1]
            },
            rightBoostRawA: {
                type: "mat4",
                value: rawData[0][2]
            },
            cellBoostRawA: {
                type: "mat4",
                value: rawData[0][3]
            },
            invCellBoostRawA: {
                type: "mat4",
                value: rawData[0][4]
            },
            boostRawB: {
                type: "float",
                value: rawData[1][0]
            },
            leftBoostRawB: {
                type: "float",
                value: rawData[1][1]
            },
            rightBoostRawB: {
                type: "float",
                value: rawData[1][2]
            },
            cellBoostRawB: {
                type: "float",
                value: rawData[1][3]
            },
            invCellBoostRawB: {
                type: "float",
                value: rawData[1][4]
            },
            facing: {
                type: "mat4",
                value: rawData[2][0]
            },
            leftFacing: {
                type: "mat4",
                value: rawData[2][1]
            },
            rightFacing: {
                type: "mat4",
                value: rawData[2][2]
            },
        }
        for (const property in this) {
            if (this.hasOwnProperty(property)) {
                if (isShaderUni(this[property])) {
                    this.uniforms[property] = {
                        type: this[property].shaderType,
                        value: this[property].shaderValue()
                    };
                }
            }
        }
    }

    /**
     * Build the vertex shader from templates files.
     * @return {string} - the code of the shader
     */
    async buildShaderVertex() {
        const response = await fetch("../shaders/vertex.glsl");
        return await response.text();
    }


    buildShaderDataHeader() {
        const res = {constants: [], uniforms: []};
        for (const property in this) {
            if (this.hasOwnProperty(property)) {
                if (isShaderCst(this[property])) {
                    res.constants.push({
                        name: property,
                        type: this[property].shaderType,
                        value: this[property].shaderValue()
                    });
                }
            }
        }
        for (const name in this.uniforms) {
            if (this.uniforms.hasOwnProperty(name)) {
                res.uniforms.push({
                    name: name,
                    type: this.uniforms[name].type
                });
            }
        }
        return res;
    }

    async buildShaderDataBackground() {
        const files = [];
        for (const list of [this._solids, this._lights]) {
            for (const item of Object.values(list)) {
                if (!files.includes(item.shaderSource)) {
                    files.push(item.shaderSource);
                }
            }
        }
        const blocks = [];
        let response;
        let xml
        const parser = new DOMParser();
        for (const file of files) {
            response = await fetch(file);
            xml = parser.parseFromString(await response.text(), 'application/xml');
            blocks.push(xml.querySelector('background').childNodes[0].nodeValue);
        }
        return {blocks: blocks};
    }

    async buildShaderDataItems() {
        for (const solid of this.listSolids) {
            await solid.glslBuildData();
        }
        for (const light of this.listLights) {
            await light.glslBuildData();
        }
        return {
            solids: this.listSolids,
            lights: this.listLights
        };
    }


    /**
     * Build the fragment shader from templates files.
     * @return {string} - the code of the shader
     */
    async buildShaderFragment() {
        const header = this.buildShaderDataHeader();
        const background = await this.buildShaderDataBackground();
        const items = await this.buildShaderDataItems();


        // A list of pairs (file, data)
        // - file is a path a a shader file
        // - data are the data passed to the template (if undefined, the file is just a plain GLSL file)
        const shaders = [
            {file: 'shaders/header.glsl', data: header},
            {file: this.geom.shader, data: undefined},
            {file: 'shaders/geometry/commons.glsl', data: undefined},
            {file: 'shaders/items/abstract.glsl', data: undefined},
            {file: 'shaders/background.glsl', data: background},
            {file: 'shaders/setup.glsl', data: items},
            {file: 'shaders/sdf.glsl', data: items},
            {file: 'shaders/scene.glsl', data: items},
            {file: 'shaders/raymarch.glsl', data: undefined},
            {file: 'shaders/lighting.glsl', data: items},
            {file: 'shaders/main.glsl', data: undefined}
        ];

        let response;
        let template;
        let fShader = "";
        for (const shader of shaders) {
            // load the file, render the template and append the result to the shader
            response = await fetch(shader.file);
            template = await response.text();
            if (shader.data === undefined) {
                fShader = fShader + template;
            } else {
                fShader = fShader + mustache.render(template, shader.data);
            }
        }
        // console.log(fShader);

        return fShader;
    }


    initUI() {
        this.guiInfo = {
            help: function () {
                window.open('https://github.com/henryseg/non-euclidean_VR');
            },
            keyboard: this.keyboard
        };
        this.gui = new GUI();
        this.gui.close();
        this.gui.add(this.guiInfo, 'help').name("Help/About");
        const keyboardController = this.gui.add(this.guiInfo, 'keyboard', {
            QWERTY: 'us',
            AZERTY: 'fr'
        }).name("Keyboard");

        let self = this;
        keyboardController.onChange(function (value) {
            self.options.pureJS.keyboard = value;
            self._keyboardControls = KEYBOARD_BINDINGS[value];
        });

    }

    initStats() {
        this.stats = new Stats();
        this.stats.showPanel(0);
        document.body.appendChild(this.stats.dom);
    }


    /**
     * Init
     * Setup the general WebGL machinery via Three.js
     * Create a simple scene with a screen and an orthographic camera
     * Setup the shaders
     */
    async init() {
        // setup the WebGL renderer
        this._renderer = new WebGLRenderer();
        this._renderer.setPixelRatio(window.devicePixelRatio);
        this._renderer.setSize(window.innerWidth, window.innerHeight);
        document.body.appendChild(this._renderer.domElement);
        this.resolution.set(window.innerWidth, window.innerHeight).multiplyScalar(window.devicePixelRatio);

        // setup the camera
        this._camera = new OrthographicCamera(-1, 1, 1, -1, 0, 1);

        // build the scene with a single screen
        this._scene = new Scene();
        const geometry = new PlaneBufferGeometry(2, 2);
        this.setupUniforms();
        let material = new ShaderMaterial({
            uniforms: this.uniforms,
            vertexShader: await this.buildShaderVertex(),
            fragmentShader: await this.buildShaderFragment(),
            transparent: true
        });
        const mesh = new Mesh(geometry, material);
        this._scene.add(mesh);

        this.appendTitle();
        this.initUI();
        this.initStats();
        this.addEventListeners();
    }

    /**
     * Animates the simulation
     */
    animate() {
        let self = this;
        window.requestAnimationFrame(function () {
            self.animate();
        });

        this.updatePosition();
        this._renderer.render(this._scene, this._camera);
        this.stats.update();
    }

    async run() {
        await this.init();
        this.animate();
    }

    /**
     * Update the position of the observer
     */
    updatePosition() {
        const deltaTime = this._clockPosition.getDelta();

        const deltaPosition = this._keyboardDirs.translation
            .clone()
            .multiplyScalar(this.speedTranslation * deltaTime);
        this.position.flow(deltaPosition);

        const deltaRotation = new Quaternion().setFromAxisAngle(
            this._keyboardDirs.rotation,
            0.5 * this.speedRotation * deltaTime
        );
        this.position.applyFacing(new Matrix4().makeRotationFromQuaternion(deltaRotation));

        const raw = this.position.serialize();
        this.uniforms.boostRawA.value = raw[0];
        this.uniforms.boostRawB.value = raw[1];
    }

    /**
     * Action when the window is resized
     * @param {Event} event
     */
    onWindowResize(event) {
        this._renderer.setSize(window.innerWidth, window.innerHeight);
        this.resolution
            .set(window.innerWidth, window.innerHeight)
            .multiplyScalar(window.devicePixelRatio);
    }

    onKey(event) {
        if (this._keyboardBinding.hasOwnProperty(event.keyCode)) {
            event.preventDefault();
            const action = this._keyboardBinding[event.keyCode]
            const control = this._keyboardControls[action];
            const dirs = this._keyboardDirs;
            let sign;
            if (event.type === "keydown") {
                if (control.active) {
                    return;
                }
                control.active = true;
                sign = 1;
            }
            if (event.type === "keyup") {
                if (!control.active) {
                    return;
                }
                control.active = false;
                sign = -1;
            }
            switch (action) {
                case ACTION_CODES.ROTATE_X_POS:
                    dirs.rotation.x = dirs.rotation.x + sign;
                    break;
                case ACTION_CODES.ROTATE_X_NEG:
                    dirs.rotation.x = dirs.rotation.x - sign;
                    break;
                case ACTION_CODES.ROTATE_Y_POS:
                    dirs.rotation.y = dirs.rotation.y + sign;
                    break;
                case ACTION_CODES.ROTATE_Y_NEG:
                    dirs.rotation.y = dirs.rotation.y - sign;
                    break;
                case ACTION_CODES.ROTATE_Z_POS:
                    dirs.rotation.z = dirs.rotation.z + sign;
                    break;
                case ACTION_CODES.ROTATE_Z_NEG:
                    dirs.rotation.z = dirs.rotation.z - sign;
                    break;
                case ACTION_CODES.TRANSLATE_X_POS:
                    dirs.translation.x = dirs.translation.x + sign;
                    break;
                case ACTION_CODES.TRANSLATE_X_NEG:
                    dirs.translation.x = dirs.translation.x - sign;
                    break;
                case ACTION_CODES.TRANSLATE_Y_POS:
                    dirs.translation.y = dirs.translation.y + sign;
                    break;
                case ACTION_CODES.TRANSLATE_Y_NEG:
                    dirs.translation.y = dirs.translation.y - sign;
                    break;
                case ACTION_CODES.TRANSLATE_Z_POS:
                    dirs.translation.z = dirs.translation.z + sign;
                    break;
                case ACTION_CODES.TRANSLATE_Z_NEG:
                    dirs.translation.z = dirs.translation.z - sign;
                    break;
            }

        }
    }

    /**
     * Register all the event listeners
     */
    addEventListeners() {
        let self = this;
        window.addEventListener(
            "resize",
            function (event) {
                self.onWindowResize(event)
            },
            false);
        document.addEventListener(
            "keydown",
            function (event) {
                self.onKey(event);
            }
        )
        document.addEventListener(
            "keyup",
            function (event) {
                self.onKey(event);
            }
        )
    }

}


export {
    Thurston
}
