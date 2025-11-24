const std = @import("std");
const flare_error = @import("src/error.zig");
const linux = std.os.linux;
const io_uring = linux.IoUring;

pub fn file_descriptor(ring:*linux.IoUring) flare_error.tcp!*linux.io_uring_sqe{
    const server_fd = io_uring.socket(
        ring,
        1,
        linux.AF.INET,
        linux.SOCK.STREAM,
        0,
        linux.SOCK.NONBLOCK | linux.SOCK.CLOEXEC
    ) catch {
        std.debug.print("Failed to create socket\n", .{});
        return flare_error.tcp.FailedCreatingSocket;
    };
return server_fd;
}
pub fn socket_setup(ring:*linux.IoUring,fd:i32) flare_error.tcp!*linux.io_uring_sqe{
    const options: i32 = 1;
    const sock = io_uring.setsockopt(
        ring,
        2,
        fd,
        linux.SOL.SOCKET,
        linux.SO.REUSEADDR | linux.SO.REUSEPORT,
        @as([]const u8, @ptrCast(&options)),
    ) catch {
        std.debug.print("Failed to Setting Up Socket\n", .{});
        return flare_error.tcp.FailedSocketOption;
    };

    return sock;
}
pub fn binding(ring:*linux.IoUring,addr:linux.sockaddr.in,fd:i32)flare_error.tcp!*linux.io_uring_sqe{
    const bind = io_uring.bind(
        ring,
        2,
        fd,
        @as(*const std.posix.sockaddr,@ptrCast(&addr)),
        @sizeOf(std.posix.socklen_t),
        0
    )catch{
        std.debug.print("Failed To Binding Socket\n",.{});
        return flare_error.tcp.FailedToBindSocket;
    };
    return bind;
}
pub fn main() !void{
    var ring = try io_uring.init(256,linux.IORING_SETUP_SQPOLL | linux.IORING_SETUP_SQ_AFF);
    defer io_uring.deinit(&ring);
    const server_fd = try file_descriptor(@as(*io_uring,@ptrCast(&ring)));
    _ = try socket_setup(@as(*io_uring,@ptrCast(&ring)),server_fd.fd);
    const port: u16 = 8001; 
    var address: linux.sockaddr.in = .{
        .family = linux.AF.INET,
        .port = std.mem.nativeToBig(u16, port),
        .addr = 0,
    };
    _ = try binding(@as(*io_uring,@ptrCast(&ring)),address,server_fd.fd);

}
