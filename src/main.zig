const std = @import("std");
const flare_error = @import("error.zig");
const linux = std.os.linux;
const io_uring = linux.IoUring;

fn setup_socket(server_fd: usize) flare_error.tcp!usize {
    const options: i32 = 1;
    
    const result = linux.setsockopt(
        @as(i32, @intCast(server_fd)),
        linux.SOL.SOCKET,
        linux.SO.REUSEADDR | linux.SO.REUSEPORT,
        @as([*]const u8, @ptrCast(&options)),
        @sizeOf(i32)
    );
    
    if (result < 0) {
        std.debug.print("Error setting socket options\n", .{});
        return flare_error.FailedSocketOption;
    }
    
    return 0;
}

pub fn main() !void {
    const server_fd = linux.socket(linux.AF.INET, linux.SOCK.STREAM, 0);
    if (server_fd < 0) {
        std.debug.print("Failed To Create Socket\n", .{});
        return flare_error.FailedCreatingSocket;
    }

    _ = try setup_socket(server_fd);

    const port: u16 = 8001;
    
    var address: linux.sockaddr.in = .{
        .family = linux.AF.INET,
        .port = std.mem.nativeToBig(u16, port),
        .addr = 0,
    };

    const bind_result = linux.bind(
        @as(i32, @intCast(server_fd)),
        @as(*const linux.sockaddr, @ptrCast(&address)),
        @sizeOf(linux.sockaddr.in)
    );

    if (bind_result < 0) {
        std.debug.print("Failed to bind socket\n", .{});
        return flare_error.FailedCreatingSocket;
    }

    const listen_result = linux.listen(@as(i32, @intCast(server_fd)), 3);
    if (listen_result < 0) {
        std.debug.print("Failed to listen\n", .{});
        return flare_error.FailedCreatingSocket;
    }

    std.debug.print("Server Listening At Port: {d}\n", .{port});

    var client_addr: linux.sockaddr.in = undefined;
    var addrlen: linux.socklen_t = @sizeOf(linux.sockaddr.in);
    var buffer: [1024]u8 = undefined;

    while (true) {
        const new_socket = linux.accept(
            @as(i32, @intCast(server_fd)),
            @as(*linux.sockaddr, @ptrCast(&client_addr)),
            &addrlen,
        );

        if (new_socket < 0) {
            std.debug.print("Failed to accept connection\n", .{});
            continue;
        }

        var bytes_read:usize = undefined;
        while (true) {
            bytes_read= linux.read(
                @as(i32, @intCast(new_socket)),
                &buffer,
                buffer.len,
        );
            _= linux.sendto(
                @as(i32, @intCast(new_socket)),
                &buffer,
                bytes_read,
                0,
                @as(*linux.sockaddr, @ptrCast(&client_addr)),
                addrlen
            );
            if(bytes_read <= 0){
                std.debug.print("Connection Closed\n",.{});
                break;
            }
            std.debug.print("Received Data: {s}\n", .{buffer[0..@as(usize, @intCast(bytes_read))]});
        }

        _ = linux.close(@as(i32, @intCast(new_socket)));
    }
}
