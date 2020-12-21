package com.lukaklacar.raytracer;

import com.badlogic.gdx.ApplicationAdapter;
import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.InputProcessor;
import com.badlogic.gdx.graphics.GL20;
import com.badlogic.gdx.graphics.Pixmap;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.graphics.glutils.ShaderProgram;
import com.badlogic.gdx.math.Vector2;

public class Raytracer extends ApplicationAdapter implements InputProcessor {
    private int width;
    private int height;
    private SpriteBatch batch;
    private ShaderProgram shader;
    private float time;
    private final Vector2 mouse = new Vector2(0, 0);

    @Override
    public void create() {
        width = Gdx.graphics.getWidth();
        height = Gdx.graphics.getHeight();

        batch = new SpriteBatch();
        ShaderProgram.pedantic = false;
        shader = new ShaderProgram(Gdx.files.internal("vertex.glsl"), Gdx.files.internal("fragment.glsl"));
        if (!shader.isCompiled()) {
            var log = shader.getLog();
            System.out.println(log);
        }

        Gdx.input.setInputProcessor(this);
    }

    @Override
    public void render() {
        Gdx.gl.glClearColor(0, 0, 0, 1);
        Gdx.gl.glClear(GL20.GL_COLOR_BUFFER_BIT);
        Gdx.graphics.setTitle(Integer.toString(Gdx.graphics.getFramesPerSecond()));

        time += Gdx.graphics.getDeltaTime();
        shader.bind();
        shader.setUniformf("resolution", new Vector2(width, height));
        shader.setUniformf("time", time);
        shader.setUniformf("mouse", mouse);

        batch.begin();
        batch.setShader(shader);
        batch.draw(new Texture(new Pixmap(width, height, Pixmap.Format.RGBA8888)), 0, 0);
        batch.end();

    }

    @Override
    public boolean keyDown(int keycode) {
        return false;
    }

    @Override
    public boolean keyUp(int keycode) {
        return false;
    }

    @Override
    public boolean keyTyped(char character) {
        return false;
    }

    @Override
    public boolean touchDown(int screenX, int screenY, int pointer, int button) {
        return false;
    }

    @Override
    public boolean touchUp(int screenX, int screenY, int pointer, int button) {
        return false;
    }

    @Override
    public boolean touchDragged(int screenX, int screenY, int pointer) {
        return false;
    }

    @Override
    public boolean mouseMoved(int screenX, int screenY) {
        mouse.set(screenX, height - screenY);
        return false;
    }

    @Override
    public boolean scrolled(float amountX, float amountY) {
        return false;
    }
}
