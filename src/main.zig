const std = @import("std");

// ============================================================================
// COSMIC VOID STRIKER - 3D Space Shooter Game (ASCII)
// ============================================================================
// Controls: WASD move, Q/E rotate, SPACE fire, R reload, ESC quit
// A 3D space combat game where you pilot a spaceship through cosmic dangers
// ============================================================================

const math = std.math;
const mem = std.mem;
const time = std.time;

// Screen dimensions for ASCII rendering
const SCREEN_WIDTH: i32 = 80;
const SCREEN_HEIGHT: i32 = 40;
const FPS_TARGET: u64 = 30;

// Game constants
const PLAYER_SPEED: f32 = 5.0;
const PLAYER_ROTATION_SPEED: f32 = 2.5;
const BULLET_SPEED: f32 = 20.0;
const ASTEROID_SPEED_MIN: f32 = 2.0;
const ASTEROID_SPEED_MAX: f32 = 5.0;
const SPAWN_RATE: f64 = 2.0;
const MAX_ASTEROIDS: usize = 15;
const MAX_BULLETS: usize = 30;
const MAX_PARTICLES: usize = 100;
const MAX_STARS: usize = 100;

// ============================================================================
// Vector3 - 3D Mathematics
// ============================================================================
const Vector3 = struct {
    x: f32, y: f32, z: f32,

    pub fn init(x: f32, y: f32, z: f32) Vector3 {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn zero() Vector3 {
        return .{ .x = 0, .y = 0, .z = 0 };
    }

    pub fn add(self: Vector3, other: Vector3) Vector3 {
        return .{ .x = self.x + other.x, .y = self.y + other.y, .z = self.z + other.z };
    }

    pub fn sub(self: Vector3, other: Vector3) Vector3 {
        return .{ .x = self.x - other.x, .y = self.y - other.y, .z = self.z - other.z };
    }

    pub fn scale(self: Vector3, scalar: f32) Vector3 {
        return .{ .x = self.x * scalar, .y = self.y * scalar, .z = self.z * scalar };
    }

    pub fn length(self: Vector3) f32 {
        return @sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
    }

    pub fn distance(self: Vector3, other: Vector3) f32 {
        return self.sub(other).length();
    }

    pub fn normalize(self: Vector3) Vector3 {
        const len = self.length();
        if (len < 0.0001) return Vector3.zero();
        return self.scale(1.0 / len);
    }

    pub fn rotateY(self: Vector3, angle: f32) Vector3 {
        const cos_a = @cos(angle);
        const sin_a = @sin(angle);
        return .{
            .x = self.x * cos_a - self.z * sin_a,
            .y = self.y,
            .z = self.x * sin_a + self.z * cos_a,
        };
    }
};

// ============================================================================
// Matrix4x4 - Transformation Matrix
// ============================================================================
const Matrix4x4 = struct {
    data: [4][4]f32,

    pub fn identity() Matrix4x4 {
        var m = Matrix4x4{ .data = [_][4]f32{[_]f32{0} ** 4} ** 4 };
        m.data[0][0] = 1; m.data[1][1] = 1; m.data[2][2] = 1; m.data[3][3] = 1;
        return m;
    }

    pub fn translation(x: f32, y: f32, z: f32) Matrix4x4 {
        var m = Matrix4x4.identity();
        m.data[0][3] = x; m.data[1][3] = y; m.data[2][3] = z;
        return m;
    }

    pub fn rotationY(angle: f32) Matrix4x4 {
        var m = Matrix4x4.identity();
        const c = @cos(angle);
        const s = @sin(angle);
        m.data[0][0] = c; m.data[0][2] = s; m.data[2][0] = -s; m.data[2][2] = c;
        return m;
    }

    pub fn perspective(fov: f32, aspect: f32, near: f32, far: f32) Matrix4x4 {
        var m = Matrix4x4{ .data = [_][4]f32{[_]f32{0} ** 4} ** 4 };
        const tan_half_fov = @tan(fov / 2.0);
        m.data[0][0] = 1.0 / (aspect * tan_half_fov);
        m.data[1][1] = 1.0 / tan_half_fov;
        m.data[2][2] = -(far + near) / (far - near);
        m.data[2][3] = -(2.0 * far * near) / (far - near);
        m.data[3][2] = -1.0;
        return m;
    }

    pub fn multiply(self: Matrix4x4, other: Matrix4x4) Matrix4x4 {
        var result = Matrix4x4.identity();
        for (0..4) |row| {
            for (0..4) |col| {
                var sum: f32 = 0;
                for (0..4) |k| { sum += self.data[row][k] * other.data[k][col]; }
                result.data[row][col] = sum;
            }
        }
        return result;
    }

    pub fn transformPoint(self: Matrix4x4, point: Vector3) Vector3 {
        const w = self.data[3][0] * point.x + self.data[3][1] * point.y + 
                  self.data[3][2] * point.z + self.data[3][3];
        if (@abs(w) < 0.0001) return point;
        return .{
            .x = (self.data[0][0] * point.x + self.data[0][1] * point.y + 
                  self.data[0][2] * point.z + self.data[0][3]) / w,
            .y = (self.data[1][0] * point.x + self.data[1][1] * point.y + 
                  self.data[1][2] * point.z + self.data[1][3]) / w,
            .z = (self.data[2][0] * point.x + self.data[2][1] * point.y + 
                  self.data[2][2] * point.z + self.data[2][3]) / w,
        };
    }
};

// ============================================================================
// Input State
// ============================================================================
const InputState = struct {
    forward: bool = false, backward: bool = false,
    strafe_left: bool = false, strafe_right: bool = false,
    turn_left: bool = false, turn_right: bool = false,
    fire: bool = false, reload: bool = false,

    pub fn init() InputState { return .{}; }
};

// ============================================================================
// Game Entities
// ============================================================================
const Player = struct {
    position: Vector3, rotation: f32, health: u32, score: u32, ammo: u32, max_ammo: u32,

    pub fn init() Player {
        return .{ .position = Vector3.init(0, 0, 15), .rotation = 0, .health = 100, .score = 0, .ammo = 30, .max_ammo = 30 };
    }

    pub fn update(self: *Player, dt: f32, input: InputState) void {
        if (input.turn_left) self.rotation -= PLAYER_ROTATION_SPEED * dt;
        if (input.turn_right) self.rotation += PLAYER_ROTATION_SPEED * dt;
        var move_dir = Vector3.init(0, 0, 0);
        if (input.forward) move_dir = move_dir.add(Vector3.init(0, 0, -1));
        if (input.backward) move_dir = move_dir.add(Vector3.init(0, 0, 1));
        if (input.strafe_left) move_dir = move_dir.add(Vector3.init(-1, 0, 0));
        if (input.strafe_right) move_dir = move_dir.add(Vector3.init(1, 0, 0));
        if (move_dir.length() > 0) {
            move_dir = move_dir.normalize().rotateY(self.rotation);
            self.position = self.position.add(move_dir.scale(PLAYER_SPEED * dt));
            const bound: f32 = 40;
            self.position.x = @clamp(self.position.x, -bound, bound);
            self.position.z = @clamp(self.position.z, -bound, bound);
        }
    }

    pub fn getForwardDirection(self: Player) Vector3 {
        return Vector3.init(0, 0, -1).rotateY(self.rotation);
    }
};

const Bullet = struct {
    position: Vector3, direction: Vector3, active: bool, lifetime: f32,

    pub fn init(position: Vector3, direction: Vector3) Bullet {
        return .{ .position = position, .direction = direction.normalize(), .active = true, .lifetime = 3.0 };
    }

    pub fn update(self: *Bullet, dt: f32) void {
        if (!self.active) return;
        self.position = self.position.add(self.direction.scale(BULLET_SPEED * dt));
        self.lifetime -= dt;
        if (self.lifetime <= 0) self.active = false;
    }
};

const Asteroid = struct {
    position: Vector3, velocity: Vector3, radius: f32, active: bool, shape_seed: u32,

    pub fn init(position: Vector3, velocity: Vector3, radius: f32, seed: u32) Asteroid {
        return .{ .position = position, .velocity = velocity, .radius = radius, .active = true, .shape_seed = seed };
    }

    pub fn update(self: *Asteroid, dt: f32) void {
        if (!self.active) return;
        self.position = self.position.add(self.velocity.scale(dt));
        if (self.position.z > 50 or self.position.z < -50) self.active = false;
    }

    pub fn getSurfaceChar(self: Asteroid, lx: f32, ly: f32, lz: f32) u8 {
        const noise = @mod(@as(f32, @floatFromInt(self.shape_seed)) * 0.1 + lx * 2 + ly * 3 + lz * 4, 1.0);
        if (noise > 0.8) return '#';
        if (noise > 0.6) return '@';
        if (noise > 0.4) return '%';
        if (noise > 0.2) return '*';
        return '.';
    }
};

const Particle = struct {
    position: Vector3, velocity: Vector3, lifetime: f32, max_lifetime: f32,

    pub fn init(position: Vector3, velocity: Vector3) Particle {
        return .{ .position = position, .velocity = velocity, .lifetime = 1.0, .max_lifetime = 1.0 };
    }

    pub fn update(self: *Particle, dt: f32) bool {
        if (self.lifetime <= 0) return false;
        self.position = self.position.add(self.velocity.scale(dt));
        self.velocity = self.velocity.scale(0.95);
        self.lifetime -= dt;
        return self.lifetime > 0;
    }
};

const Star = struct {
    x: f32, y: f32, z: f32, brightness: f32, twinkle_speed: f32,

    pub fn init(rng: *std.Random.DefaultRng) Star {
        const r = rng.random();
        return .{
            .x = (r.float(f32) - 0.5) * 100, .y = (r.float(f32) - 0.5) * 50,
            .z = (r.float(f32) - 0.5) * 100 - 50, .brightness = r.float(f32),
            .twinkle_speed = 0.5 + r.float(f32) * 2.0,
        };
    }

    pub fn update(self: *Star, t: f64) void {
        self.brightness = 0.5 + 0.5 * @sin(@as(f32, @floatCast(t)) * self.twinkle_speed);
    }
};

// ============================================================================
// Game State
// ============================================================================
const GameState = struct {
    player: Player, bullets: [MAX_BULLETS]Bullet, asteroids: [MAX_ASTEROIDS]Asteroid,
    particles: [MAX_PARTICLES]Particle, stars: [MAX_STARS]Star,
    is_running: bool, game_time: f64, spawn_timer: f64, wave: u32,

    pub fn init(allocator: mem.Allocator) !GameState {
        _ = allocator;
        var state = GameState{
            .player = Player.init(), .bullets = undefined, .asteroids = undefined,
            .particles = undefined, .stars = undefined, .is_running = true,
            .game_time = 0, .spawn_timer = 0, .wave = 1,
        };
        for (&state.bullets) |*b| { b.* = Bullet.init(Vector3.zero(), Vector3.init(0, 0, -1)); b.active = false; }
        for (&state.asteroids) |*a| { a.* = Asteroid.init(Vector3.zero(), Vector3.zero(), 1, 0); a.active = false; }
        for (&state.particles) |*p| { p.* = Particle.init(Vector3.zero(), Vector3.zero()); p.lifetime = 0; }
        var rng = std.Random.DefaultRng.init(42);
        for (&state.stars) |*s| { s.* = Star.init(&rng); }
        return state;
    }

    pub fn deinit(self: *GameState, allocator: mem.Allocator) void { _ = self; _ = allocator; }

    pub fn fireBullet(self: *GameState) void {
        if (self.player.ammo == 0) return;
        for (&self.bullets) |*b| {
            if (!b.active) {
                const dir = self.player.getForwardDirection();
                b.* = Bullet.init(self.player.position.add(dir.scale(2)), dir);
                self.player.ammo -= 1;
                break;
            }
        }
    }

    pub fn spawnAsteroid(self: *GameState, rng: *std.Random.DefaultRng) void {
        for (&self.asteroids) |*a| {
            if (!a.active) {
                const r = rng.random();
                const speed = ASTEROID_SPEED_MIN + r.float(f32) * (ASTEROID_SPEED_MAX - ASTEROID_SPEED_MIN);
                a.* = Asteroid.init(
                    Vector3.init((r.float(f32) - 0.5) * 60, (r.float(f32) - 0.5) * 30, 40),
                    Vector3.init((r.float(f32) - 0.5) * 2, (r.float(f32) - 0.5) * 1, -speed),
                    1.5 + r.float(f32) * 3.0, @as(u32, @intFromFloat(r.float(f32) * 10000)),
                );
                break;
            }
        }
    }

    pub fn createExplosion(self: *GameState, pos: Vector3, count: u32) void {
        var created: u32 = 0;
        for (&self.particles) |*p| {
            if (p.lifetime <= 0 and created < count) {
                var rng = std.Random.DefaultRng.init(@intFromFloat(pos.x * 1000 + pos.y * 100));
                const r = rng.random();
                p.* = Particle.init(pos, Vector3.init((r.float(f32) - 0.5) * 10, (r.float(f32) - 0.5) * 10, (r.float(f32) - 0.5) * 10));
                created += 1;
            }
        }
    }

    pub fn checkCollisions(self: *GameState) void {
        for (&self.bullets) |*b| {
            if (!b.active) continue;
            for (&self.asteroids) |*a| {
                if (!a.active) continue;
                if (b.position.distance(a.position) < a.radius) {
                    b.active = false; a.active = false;
                    self.player.score += 100;
                    self.createExplosion(a.position, 15);
                    break;
                }
            }
        }
        for (&self.asteroids) |*a| {
            if (!a.active) continue;
            if (self.player.position.distance(a.position) < a.radius + 1.0) {
                a.active = false;
                self.player.health = if (self.player.health > 20) self.player.health - 20 else 0;
                self.createExplosion(self.player.position, 25);
                if (self.player.health == 0) self.is_running = false;
            }
        }
    }

    pub fn update(self: *GameState, dt: f32, input: InputState) void {
        if (!self.is_running) return;
        self.game_time += dt;
        self.player.update(dt, input);
        if (input.fire) self.fireBullet();
        if (input.reload) self.player.ammo = self.player.max_ammo;
        self.spawn_timer += dt;
        if (self.spawn_timer >= SPAWN_RATE) {
            self.spawn_timer = 0;
            var rng = std.Random.DefaultRng.init(@intFromFloat(self.game_time * 1000));
            self.spawnAsteroid(&rng);
        }
        for (&self.bullets) |*b| { b.update(dt); }
        for (&self.asteroids) |*a| { a.update(dt); }
        for (&self.stars) |*s| { s.update(self.game_time); }
        for (&self.particles) |*p| { _ = p.update(dt); }
        self.checkCollisions();
        const new_wave = @as(u32, @intFromFloat(self.game_time / 30)) + 1;
        if (new_wave > self.wave) {
            self.wave = new_wave;
            self.player.ammo = self.player.max_ammo;
            self.player.health = @min(self.player.health + 20, 100);
        }
    }
};

// ============================================================================
// ASCII Renderer
// ============================================================================
const Renderer = struct {
    buffer: [][]u8, depth_buffer: [][]f32, width: i32, height: i32,

    pub fn init(allocator: mem.Allocator, w: i32, h: i32) !Renderer {
        const buf = try allocator.alloc([]u8, @intCast(h));
        errdefer allocator.free(buf);
        const db = try allocator.alloc([]f32, @intCast(h));
        errdefer allocator.free(db);
        for (buf) |*row| { row.* = try allocator.alloc(u8, @intCast(w)); }
        for (db) |*row| { row.* = try allocator.alloc(f32, @intCast(w)); }
        return .{ .buffer = buf, .depth_buffer = db, .width = w, .height = h };
    }

    pub fn deinit(self: *Renderer, allocator: mem.Allocator) void {
        for (self.buffer) |row| { allocator.free(row); }
        allocator.free(self.buffer);
        for (self.depth_buffer) |row| { allocator.free(row); }
        allocator.free(self.depth_buffer);
    }

    pub fn clear(self: *Renderer) void {
        for (self.buffer) |row| { @memset(row, ' '); }
        for (self.depth_buffer) |row| { @memset(row, math.inf(f32)); }
    }

    pub fn plot(self: *Renderer, x: i32, y: i32, depth: f32, char: u8) void {
        if (x < 0 or x >= self.width or y < 0 or y >= self.height) return;
        if (depth > self.depth_buffer[@intCast(y)][@intCast(x)]) return;
        self.depth_buffer[@intCast(y)][@intCast(x)] = depth;
        self.buffer[@intCast(y)][@intCast(x)] = char;
    }

    pub fn drawLine3D(self: *Renderer, start: Vector3, end: Vector3, vm: Matrix4x4, pm: Matrix4x4, char: u8) void {
        const sp = pm.transformPoint(vm.transformPoint(start));
        const ep = pm.transformPoint(vm.transformPoint(end));
        const sx = @as(i32, @intFromFloat((sp.x + 1) * 0.5 * @as(f32, @floatFromInt(self.width))));
        const sy = @as(i32, @intFromFloat((1 - sp.y) * 0.5 * @as(f32, @floatFromInt(self.height))));
        const ex = @as(i32, @intFromFloat((ep.x + 1) * 0.5 * @as(f32, @floatFromInt(self.width))));
        const ey = @as(i32, @intFromFloat((1 - ep.y) * 0.5 * @as(f32, @floatFromInt(self.height))));
        const dx = ex - sx;
        const dy = ey - sy;
        const steps = @max(@abs(dx), @abs(dy));
        if (steps == 0) { self.plot(sx, sy, sp.z, char); return; }
        const xi: f32 = @as(f32, @floatFromInt(dx)) / @as(f32, @floatFromInt(steps));
        const yi: f32 = @as(f32, @floatFromInt(dy)) / @as(f32, @floatFromInt(steps));
        const zi: f32 = (ep.z - sp.z) / @as(f32, @floatFromInt(steps));
        var xf: f32 = @as(f32, @floatFromInt(sx));
        var yf: f32 = @as(f32, @floatFromInt(sy));
        var zf: f32 = sp.z;
        var i: i32 = 0;
        while (i <= steps) : (i += 1) {
            self.plot(@as(i32, @intFromFloat(xf)), @as(i32, @intFromFloat(yf)), zf, char);
            xf += xi; yf += yi; zf += zi;
        }
    }

    pub fn drawAsteroid(self: *Renderer, asteroid: Asteroid, vm: Matrix4x4, pm: Matrix4x4) void {
        if (!asteroid.active) return;
        const tf = vm.transformPoint(asteroid.position);
        if (tf.z > -1) return;
        const pj = pm.transformPoint(tf);
        if (pj.z < -1 or pj.z > 1) return;
        const scx = (pj.x + 1) * 0.5 * @as(f32, @floatFromInt(self.width));
        const scy = (1 - pj.y) * 0.5 * @as(f32, @floatFromInt(self.height));
        const sz = @as(i32, @intFromFloat(asteroid.radius * 3 / -tf.z * @as(f32, @floatFromInt(self.width)) / 20));
        const cx = @as(i32, @intFromFloat(scx));
        const cy = @as(i32, @intFromFloat(scy));
        for (-sz..sz + 1) |dyi| {
            for (-sz..sz + 1) |dxi| {
                const dsq = dxi * dxi + dyi * dyi;
                if (dsq <= sz * sz) {
                    const px = cx + dxi;
                    const py = cy + dyi;
                    if (px >= 0 and px < self.width and py >= 0 and py < self.height) {
                        const divisor = if (sz == 0) 1 else sz;
                        const lx = @as(f32, @floatFromInt(dxi)) / @as(f32, @floatFromInt(divisor));
                        const ly = @as(f32, @floatFromInt(dyi)) / @as(f32, @floatFromInt(divisor));
                        const lz = @sqrt(@max(0, 1 - lx * lx - ly * ly));
                        self.plot(px, py, pj.z, asteroid.getSurfaceChar(lx, ly, lz));
                    }
                }
            }
        }
    }

    pub fn drawBullet(self: *Renderer, bullet: Bullet, vm: Matrix4x4, pm: Matrix4x4) void {
        if (!bullet.active) return;
        self.drawLine3D(bullet.position, bullet.position.sub(bullet.direction.scale(1.5)), vm, pm, '-');
    }

    pub fn drawPlayer(self: *Renderer, player: Player, vm: Matrix4x4, pm: Matrix4x4) void {
        const nose = player.position;
        const lw = player.position.add(Vector3.init(-2, 1, 2).rotateY(player.rotation));
        const rw = player.position.add(Vector3.init(2, 1, 2).rotateY(player.rotation));
        const tail = player.position.add(Vector3.init(0, 0, 3).rotateY(player.rotation));
        self.drawLine3D(nose, lw, vm, pm, '^');
        self.drawLine3D(nose, rw, vm, pm, '^');
        self.drawLine3D(lw, tail, vm, pm, '=');
        self.drawLine3D(rw, tail, vm, pm, '=');
    }

    pub fn drawParticles(self: *Renderer, particles: []Particle, vm: Matrix4x4, pm: Matrix4x4) void {
        for (particles) |p| {
            if (p.lifetime <= 0) continue;
            const tf = vm.transformPoint(p.position);
            if (tf.z > -1) continue;
            const pj = pm.transformPoint(tf);
            const scx = @as(i32, @intFromFloat((pj.x + 1) * 0.5 * @as(f32, @floatFromInt(self.width))));
            const scy = @as(i32, @intFromFloat((1 - pj.y) * 0.5 * @as(f32, @floatFromInt(self.height))));
            const alpha = p.lifetime / p.max_lifetime;
            const chars = [_]u8{ ' ', '.', '*', '+', 'o', 'O', '#' };
            const ci = @as(usize, @intFromFloat(alpha * @as(f32, @floatFromInt(chars.len - 1))));
            self.plot(scx, scy, pj.z, chars[ci]);
        }
    }

    pub fn drawStars(self: *Renderer, stars: []Star, player: Player) void {
        for (stars) |star| {
            const rx = star.x - player.position.x * 0.5;
            const ry = star.y - player.position.y * 0.5;
            const rz = star.z - player.position.z * 0.5;
            if (rz < -5) {
                const scale = 20.0 / -rz;
                const sx = @as(i32, @intFromFloat(self.width / 2 + rx * scale));
                const sy = @as(i32, @intFromFloat(self.height / 2 + ry * scale));
                if (sx >= 0 and sx < self.width and sy >= 0 and sy < self.height) {
                    const bc = if (star.brightness > 0.8) '★' else if (star.brightness > 0.5) '☆' else if (star.brightness > 0.3) '·' else '*';
                    self.buffer[@intCast(sy)][@intCast(sx)] = bc;
                }
            }
        }
    }

    pub fn render(self: *Renderer, game: *GameState) void {
        self.clear();
        const vm = Matrix4x4.translation(-game.player.position.x, -game.player.position.y, -game.player.position.z).multiply(Matrix4x4.rotationY(-game.player.rotation));
        const aspect = @as(f32, @floatFromInt(self.width)) / @as(f32, @floatFromInt(self.height));
        const pm = Matrix4x4.perspective(math.pi / 4.0, aspect, 0.1, 100.0);
        self.drawStars(&game.stars, game.player);
        for (&game.asteroids) |a| { self.drawAsteroid(a, vm, pm); }
        for (&game.bullets) |b| { self.drawBullet(b, vm, pm); }
        self.drawPlayer(game.player, vm, pm);
        self.drawParticles(&game.particles, vm, pm);
    }

    pub fn print(self: *Renderer, writer: anytype, game: *GameState) !void {
        try writer.writeAll("\x1b[2J\x1b[H");
        try writer.writeAll("\x1b[1;36m╔══════════════════════════════════════════════════════════════╗\x1b[0m\n");
        try writer.writeAll("\x1b[1;36m║\x1b[0m  \x1b[1;33m★ COSMIC VOID STRIKER ★\x1b[0m                              \x1b[1;36m║\x1b[0m\n");
        try writer.writeAll("\x1b[1;36m╠══════════════════════════════════════════════════════════════╣\x1b[0m\n");
        const hc = if (game.player.health > 50) 2 else if (game.player.health > 20) 3 else 1;
        try writer.print("\x1b[1;36m║\x1b[0m  HP:\x1b[1;3{d}m{d:>3}\x1b[0m  Score:\x1b[1;32m{d:>6}\x1b[0m  Ammo:\x1b[1;33m{d:>2}/{d}\x1b[0m  Wave:\x1b[1;35m{d}\x1b[0m       \x1b[1;36m║\x1b[0m\n", .{ hc, game.player.health, game.player.score, game.player.ammo, game.player.max_ammo, game.wave });
        try writer.writeAll("\x1b[1;36m╠══════════════════════════════════════════════════════════════╣\x1b[0m\n");
        for (self.buffer) |row| {
            try writer.writeAll("\x1b[1;36m║\x1b[0m  ");
            for (row) |c| {
                if (c == ' ') try writer.writeAll(" ");
                else if (c == '★' or c == '☆') try writer.print("\x1b[1;37m{c}\x1b[0m", .{c});
                else if (c == '#' or c == '@') try writer.print("\x1b[1;31m{c}\x1b[0m", .{c});
                else if (c == '-' or c == '^') try writer.print("\x1b[1;33m{c}\x1b[0m", .{c});
                else try writer.print("\x1b[1;37m{c}\x1b[0m", .{c});
            }
            try writer.writeAll("  \x1b[1;36m║\x1b[0m\n");
        }
        try writer.writeAll("\x1b[1;36m╠══════════════════════════════════════════════════════════════╣\x1b[0m\n");
        try writer.writeAll("\x1b[1;36m║\x1b[0m  \x1b[1;37mW/S\x1b[0m:Move  \x1b[1;37mA/D\x1b[0m:Strafe  \x1b[1;37mQ/E\x1b[0m:Rotate  \x1b[1;37mSPACE\x1b[0m:Fire  \x1b[1;37mESC\x1b[0m:Quit  \x1b[1;36m║\x1b[0m\n");
        try writer.writeAll("\x1b[1;36m╚══════════════════════════════════════════════════════════════╝\x1b[0m\n");
        if (!game.is_running) {
            try writer.writeAll("\n\x1b[1;31m═══════════════════════════════════════════════════════════════\x1b[0m\n");
            try writer.writeAll("\x1b[1;31m              GAME OVER - Final Score: \x1b[1;33m{d}\x1b[0m\n", .{game.player.score});
            try writer.writeAll("\x1b[1;31m                 Press R to Restart or ESC to Quit\x1b[0m\n");
            try writer.writeAll("\x1b[1;31m═══════════════════════════════════════════════════════════════\x1b[0m\n");
        }
    }
};

// ============================================================================
// Main Entry Point
// ============================================================================
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const stdout = std.io.getStdOut().writer();

    try stdout.writeAll("\x1b[2J\x1b[H");
    try stdout.writeAll("\x1b[1;36m");
    try stdout.writeAll("╔══════════════════════════════════════════════════════════════╗\n");
    try stdout.writeAll("║                                                              ║\n");
    try stdout.writeAll("║          \x1b[1;33m★ COSMIC VOID STRIKER ★\x1b[1;36m                          ║\n");
    try stdout.writeAll("║                                                              ║\n");
    try stdout.writeAll("║     A 3D Space Shooter Built in Zig 0.14                     ║\n");
    try stdout.writeAll("║                                                              ║\n");
    try stdout.writeAll("╠══════════════════════════════════════════════════════════════╣\n");
    try stdout.writeAll("║                                                              ║\n");
    try stdout.writeAll("║  \x1b[1;37mCONTROLS:\x1b[1;36m                                                    ║\n");
    try stdout.writeAll("║    W/S       - Forward/Backward (Throttle)                   ║\n");
    try stdout.writeAll("║    A/D       - Strafe Left/Right                             ║\n");
    try stdout.writeAll("║    Q/E       - Rotate Left/Right (Yaw)                       ║\n");
    try stdout.writeAll("║    SPACE     - Fire Weapons                                  ║\n");
    try stdout.writeAll("║    R         - Reload Ammo                                   ║\n");
    try stdout.writeAll("║    ESC       - Quit Game                                     ║\n");
    try stdout.writeAll("║                                                              ║\n");
    try stdout.writeAll("║  \x1b[1;37mOBJECTIVE:\x1b[1;36m                                                   ║\n");
    try stdout.writeAll("║    Destroy asteroids, survive waves, achieve high score!     ║\n");
    try stdout.writeAll("║    Watch out for collisions - they drain your health!        ║\n");
    try stdout.writeAll("║                                                              ║\n");
    try stdout.writeAll("╚══════════════════════════════════════════════════════════════╝\n");
    try stdout.writeAll("\x1b[0m\n");
    try stdout.writeAll("\n  Press ENTER to launch into the cosmic void...\n");

    { var buf: [1]u8 = undefined; while (true) { _ = try std.io.getStdIn().read(&buf); if (buf[0] == '\n' or buf[0] == '\r') break; } }

    var game = try GameState.init(allocator);
    defer game.deinit(allocator);
    var renderer = try Renderer.init(allocator, SCREEN_WIDTH, SCREEN_HEIGHT);
    defer renderer.deinit(allocator);

    const frame_time: f64 = 1.0 / @as(f64, @floatFromInt(FPS_TARGET));
    var last_time = time.timestamp();
    var accumulator: f64 = 0;
    var input_state = InputState.init();

    while (true) {
        const current_time = @as(f64, @floatFromInt(time.timestamp()));
        const delta = current_time - last_time;
        last_time = current_time;
        accumulator += delta;

        const buf_size = 16;
        var buf: [buf_size]u8 = undefined;
        const bytes_read = std.io.getStdIn().read(&buf) catch 0;
        
        if (bytes_read > 0) {
            var i: usize = 0;
            while (i < bytes_read) : (i += 1) {
                switch (buf[i]) {
                    'w', 'W' => input_state.forward = true,
                    's', 'S' => input_state.backward = true,
                    'a', 'A' => input_state.strafe_left = true,
                    'd', 'D' => input_state.strafe_right = true,
                    'q', 'Q' => input_state.turn_left = true,
                    'e', 'E' => input_state.turn_right = true,
                    ' ' => input_state.fire = true,
                    'r', 'R' => { input_state.reload = true; if (!game.is_running) game = try GameState.init(allocator); },
                    27 => break,
                    else => {},
                }
            }
        } else { input_state = InputState.init(); }

        if (bytes_read > 0 and buf[0] == 27) break;

        while (accumulator >= frame_time) { game.update(@floatCast(frame_time), input_state); accumulator -= frame_time; }

        renderer.render(&game);
        try renderer.print(stdout, &game);

        const elapsed = time.timestamp() - last_time;
        const sleep_time = frame_time - elapsed;
        if (sleep_time > 0) time.sleep(@intFromFloat(sleep_time * time.ns_per_s));
    }

    try stdout.writeAll("\x1b[2J\x1b[H");
    try stdout.writeAll("\x1b[0m");
    try stdout.print("\n\x1b[1;36mThanks for playing COSMIC VOID STRIKER!\x1b[0m\n", .{});
    try stdout.print("Final Score: \x1b[1;33m{d}\x1b[0m\n\n", .{game.player.score});
}
