const std = @import("std");

// Matrix 4x4 structure
const Matrix4x4 = struct {
    data: [4][4]f32,

    pub fn init() Matrix4x4 {
        return .{
            .data = .{
                .{ 0.0, 0.0, 0.0, 0.0 },
                .{ 0.0, 0.0, 0.0, 0.0 },
                .{ 0.0, 0.0, 0.0, 0.0 },
                .{ 0.0, 0.0, 0.0, 0.0 },
            },
        };
    }

    pub fn set(self: *Matrix4x4, row: usize, col: usize, value: f32) void {
        if (row < 4 and col < 4) {
            self.data[row][col] = value;
        }
    }

    pub fn get(self: *const Matrix4x4, row: usize, col: usize) f32 {
        if (row < 4 and col < 4) {
            return self.data[row][col];
        }
        return 0.0;
    }

    pub fn randomize(self: *Matrix4x4, rng: *std.Random.DefaultRng) void {
        for (0..4) |row| {
            for (0..4) |col| {
                self.data[row][col] = @as(f32, @floatFromInt(rng.next().% 100)) / 10.0;
            }
        }
    }
};

// Void Space - transforms matrix values into visual multi-dimensional representation
const VoidSpace = struct {
    matrix: *Matrix4x4,
    depth_layers: u8,
    visualization_mode: VisualizationMode,

    const VisualizationMode = enum {
        ascii_2d,
        ascii_3d,
        ascii_multidimensional,
    };

    pub fn init(matrix: *Matrix4x4) VoidSpace {
        return .{
            .matrix = matrix,
            .depth_layers = 5,
            .visualization_mode = .ascii_multidimensional,
        };
    }

    pub fn renderAscii2D(self: *const VoidSpace, writer: anytype) !void {
        try writer.writeAll("\n=== 2D Matrix Visualization ===\n\n");
        for (0..4) |row| {
            for (0..4) |col| {
                const value = self.matrix.get(row, col);
                const intensity = @min(@as(usize, @intFromFloat(value * 2)), 9);
                try writer.print("{d:>6.2f} ", .{value});
            }
            try writer.writeByte('\n');
        }
        try writer.writeAll("\n");
    }

    pub fn renderAscii3D(self: *const VoidSpace, writer: anytype) !void {
        try writer.writeAll("\n=== 3D Depth Visualization ===\n\n");
        
        const symbols = [_]u8{ ' ', '.', ':', '-', '=', '+', '*', '#', '@', '█' };
        
        for (0..4) |row| {
            for (0..4) |col| {
                const value = self.matrix.get(row, col);
                const symbol_index = @min(@as(usize, @intFromFloat(value)), 9);
                try writer.print("{c}{c}{c} ", .{
                    symbols[symbol_index],
                    symbols[symbol_index],
                    symbols[symbol_index],
                });
            }
            try writer.writeByte('\n');
        }
        try writer.writeAll("\n");
    }

    pub fn renderMultiDimensional(self: *const VoidSpace, writer: anytype) !void {
        try writer.writeAll("\n╔════════════════════════════════════════════╗\n");
        try writer.writeAll("║     MULTI-DIMENSIONAL VOID SPACE VIEW      ║\n");
        try writer.writeAll("╚════════════════════════════════════════════╝\n\n");

        const symbols = [_][]const u8{
            "  ", "░░", "▒▒", "▓▓", "██", 
            "◊◊", "◆◆", "●●", "■■", "▲▲",
        };

        // Render multiple depth layers
        for (0..self.depth_layers) |layer| {
            try writer.print("─── Layer {d} ───\n", .{layer + 1});
            
            for (0..4) |row| {
                try writer.writeAll("│ ");
                for (0..4) |col| {
                    const base_value = self.matrix.get(row, col);
                    // Apply layer transformation
                    const transformed = base_value + (@as(f32, @floatFromInt(layer)) * 0.5);
                    const normalized = @mod(transformed, 10.0);
                    const symbol_index = @min(@as(usize, @intFromFloat(normalized)), 9);
                    
                    try writer.print("{s}", .{symbols[symbol_index]});
                    if (col < 3) try writer.writeAll(" ");
                }
                try writer.writeAll(" │\n");
            }
            try writer.writeAll("\n");
        }

        // Render value bars
        try writer.writeAll("═══ Value Intensity Bars ═══\n\n");
        for (0..4) |row| {
            for (0..4) |col| {
                const value = self.matrix.get(row, col);
                const bar_length = @min(@as(usize, @intFromFloat(value * 2)), 20);
                try writer.print("[{d},{d}] ", .{ row, col });
                for (0..bar_length) |_| {
                    try writer.writeAll("█");
                }
                try writer.print(" {d:.2f}\n", .{value});
            }
        }
        try writer.writeAll("\n");
    }

    pub fn renderWireframe3D(self: *const VoidSpace, writer: anytype) !void {
        try writer.writeAll("\n╔════════════════════════════════════════════╗\n");
        try writer.writeAll("║         3D WIREFRAME PROJECTION            ║\n");
        try writer.writeAll("╚════════════════════════════════════════════╝\n\n");

        const depth_scale: f32 = 0.3;
        
        for (0..4) |row| {
            for (0..4) |col| {
                const value = self.matrix.get(row, col);
                
                // Calculate 3D offset based on value
                const offset_x = @as(i32, @intFromFloat(value * depth_scale));
                const offset_y = @as(i32, @intFromFloat(value * depth_scale * 0.5));
                
                try writer.print("┌", .{});
                var i: i32 = 0;
                while (i < 3 + offset_x) : (i += 1) {
                    try writer.writeAll("─");
                }
                try writer.writeAll("┐\n");
                
                try writer.print("│{d:>4.1f}", .{value});
                i = 0;
                while (i < 1 + offset_x) : (i += 1) {
                    try writer.writeAll(" ");
                }
                try writer.writeAll("│\n");
                
                try writer.print("└", .{});
                i = 0;
                while (i < 3 + offset_x) : (i += 1) {
                    try writer.writeAll("─");
                }
                try writer.writeAll("┘  ");
            }
            try writer.writeAll("\n\n");
        }
    }
};

// Engine that manages the matrix and void space
const MatrixVoidEngine = struct {
    matrix: Matrix4x4,
    void_space: VoidSpace,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) MatrixVoidEngine {
        var matrix = Matrix4x4.init();
        var void_space = VoidSpace.init(&matrix);
        return .{
            .matrix = matrix,
            .void_space = void_space,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MatrixVoidEngine) void {
        _ = self;
    }

    pub fn updateMatrix(self: *MatrixVoidEngine, row: usize, col: usize, value: f32) void {
        self.matrix.set(row, col, value);
    }

    pub fn randomizeMatrix(self: *MatrixVoidEngine) void {
        var rng = std.Random.DefaultRng.init(42);
        self.matrix.randomize(&rng);
    }

    pub fn render(self: *const MatrixVoidEngine, writer: anytype) !void {
        try self.void_space.renderAscii2D(writer);
        try self.void_space.renderAscii3D(writer);
        try self.void_space.renderMultiDimensional(writer);
        try self.void_space.renderWireframe3D(writer);
    }

    pub fn animate(self: *MatrixVoidEngine, writer: anytype, frames: u32) !void {
        var rng = std.Random.DefaultRng.init(123);
        var frame: u32 = 0;
        
        while (frame < frames) : (frame += 1) {
            // Clear screen (ANSI escape code)
            try writer.writeAll("\x1b[2J\x1b[H");
            
            try writer.print("═══ FRAME {d} ═══\n\n", .{frame + 1});
            
            // Animate matrix values
            self.matrix.randomize(&rng);
            
            // Render current state
            try self.void_space.renderMultiDimensional(writer);
            
            try writer.print("\nPress Enter for next frame... (Frame {d}/{d})\n", .{ frame + 1, frames });
            
            // In a real application, you would wait for user input here
            // For now, we'll just continue
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.io.getStdOut().writer();

    try stdout.writeAll("\n╔═══════════════════════════════════════════════════╗\n");
    try stdout.writeAll("║     MATRIX VOID ENGINE - Zig 0.16                 ║\n");
    try stdout.writeAll("║     4x4 Matrix → Multi-Dimensional Void Space     ║\n");
    try stdout.writeAll("╚═══════════════════════════════════════════════════╝\n\n");

    // Create engine
    var engine = MatrixVoidEngine.init(allocator);
    defer engine.deinit();

    // Set some initial values
    engine.updateMatrix(0, 0, 5.5);
    engine.updateMatrix(0, 1, 3.2);
    engine.updateMatrix(0, 2, 7.8);
    engine.updateMatrix(0, 3, 2.1);
    engine.updateMatrix(1, 0, 4.4);
    engine.updateMatrix(1, 1, 6.7);
    engine.updateMatrix(1, 2, 1.9);
    engine.updateMatrix(1, 3, 8.3);
    engine.updateMatrix(2, 0, 9.1);
    engine.updateMatrix(2, 1, 2.5);
    engine.updateMatrix(2, 2, 5.0);
    engine.updateMatrix(2, 3, 3.7);
    engine.updateMatrix(3, 0, 6.2);
    engine.updateMatrix(3, 1, 4.8);
    engine.updateMatrix(3, 2, 7.3);
    engine.updateMatrix(3, 3, 1.5);

    try stdout.writeAll("Initial Matrix Values:\n");
    try stdout.writeAll("======================\n\n");

    // Render all visualizations
    try engine.render(stdout);

    // Demonstrate animation (3 frames)
    try stdout.writeAll("\n\nStarting Animation Demo (3 frames)...\n");
    try stdout.writeAll("========================================\n");
    try engine.animate(stdout, 3);

    try stdout.writeAll("\n✓ Matrix Void Engine demonstration complete!\n\n");
}
