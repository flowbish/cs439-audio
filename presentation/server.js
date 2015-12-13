var app = require('express')();
var http = require('http').Server(app);
var io = require('socket.io')(http);
var serialport = require("serialport")
var SerialPort = serialport.SerialPort
var serial = new SerialPort("/dev/ttyACM0", {
    baudrate: 115200,
    parser: serialport.parsers.readline("\n")
});

messages = []

add_message = function(msg) {
    console.log('sending message "' + msg + '"');
    messages.push(msg);
    serial.write(msg + '\n', function(err, results) {
        if (err) {
            console.log('err ' + err);
            serial = new SerialPort("/dev/ttyACM0", {
                baudrate: 115200,
                parser: serialport.parsers.readline("\n")
            });
        }
    });
}

// Setup serial connection to transmitter device
serial.on("open", function () {
    //console.log('Serial ' + serial.comName + ' open');
    serial.on('data', function(data) {
        console.log('data received: ' + data);
        messages.push(''+data);
        io.emit('chat message', ''+data);
    });
});

app.get('/', function(req, res) {
    res.sendFile(__dirname + '/index.html');
});

io.on('connection', function(socket) {
    console.log('user connected');

    // replay last messages
    for (var i = 0; i < messages.length; i++) {
        socket.emit('chat message', messages[i]);
    }

    socket.on('chat message', function(msg) {
        add_message(msg);
        io.emit('chat message', msg);
    });
});

http.listen(3000, function() {
    console.log('listening on *:3000');
});
