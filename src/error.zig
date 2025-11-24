pub const tcp = error{
    FailedCreatingSocket,
    FailedSocketOption,
    FailedToBindSocket,
    FailedToAcceptSocket,
    FailedToListenSocket
};
