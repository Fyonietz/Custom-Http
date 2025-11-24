const std = @import("std");
const flare_error = @import("src/error.zig");
const linux = std.os.linux;
const io_uring = linux.IoUring;
const OpType = enum { Accept, Read, Write };

const Request = struct {
    op: OpType,
    conn_id: u32,
    buf_id: u16,
};

var req = Request{ .op = .Read, .conn_id = 5, .buf_id = 10 };

pub fn file_descriptor(ring:*linux.IoUring) flare_error.tcp!*linux.io_uring_sqe{
    const server_fd = io_uring.socket(
        ring,
        @intFromPtr(&req),
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
pub fn accept(ring:*linux.IoUring,addr:?*std.posix.sockaddr,fd:i32,addr_len:std.posix.socklen_t)flare_error.tcp!*linux.io_uring_sqe{
    const accept_constant = io_uring.accept(
        ring,
        2,
        fd,
        addr,
        @as(?*u32,@constCast(&addr_len)),
        0
    )catch{
        std.debug.print("Failed To Accept Socket\n",.{});
        return flare_error.tcp.FailedToAcceptSocket;
    };
    return accept_constant;
}
pub fn listening(ring:*linux.IoUring,fd:i32)flare_error.tcp!*linux.io_uring_sqe{
    const listen = io_uring.listen(
        ring,
        2,
        fd,
        0,
        3
    )catch{
        std.debug.print("Failed To Accept Socket\n",.{});
        return flare_error.tcp.FailedToListenSocket;
    };
return listen;
}
pub fn main() !void{
    var ring = try io_uring.init(256,linux.IORING_SETUP_SQPOLL | linux.IORING_SETUP_SQ_AFF);
    defer io_uring.deinit(&ring);
    const server_fd = try file_descriptor(@as(*io_uring,@ptrCast(&ring)));
    _ = try socket_setup(@as(*io_uring,@ptrCast(&ring)),server_fd.fd);
    const port: u16 = 8001; 
    const address: linux.sockaddr.in = .{
        .family = linux.AF.INET,
        .port = std.mem.nativeToBig(u16, port),
        .addr = 0,
    };
    _ = try binding(@as(*io_uring,@ptrCast(&ring)),address,server_fd.fd);
    _ = try listening(@as(*io_uring,@ptrCast(&ring)),server_fd.fd);

    std.debug.print("Server Listening At Port: {d}\n", .{port});
    const address_in_posix = @as(std.posix.sockaddr.in,address);
    const client_addr: ?*std.posix.sockaddr = undefined;
    const addrlen: std.posix.socklen_t = @sizeOf(@TypeOf(address_in_posix));
    const buffer: [1024]u8 = undefined;


    while(true){
        const new_socket = try accept(
            @as(*io_uring,@ptrCast(&ring)),
            client_addr,
            server_fd.fd,
            addrlen
        );
        _ = new_socket;
        _ = buffer;
    }
}
