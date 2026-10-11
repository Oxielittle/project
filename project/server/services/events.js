let io;
const setIO = (socketServer) => { io = socketServer; };
const emitToUser = (userId, event, payload) => io?.to(`user:${userId}`).emit(event, payload);
const emitAll = (event, payload) => io?.emit(event, payload);
module.exports = { setIO, emitToUser, emitAll };
