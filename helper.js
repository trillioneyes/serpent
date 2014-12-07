var canvas = document.getElementById("snake_canvas");
var context = canvas.getContext("2d");

function game_height() {
    return canvas.height;
}
function game_width() {
    return canvas.width;
}

var last_key = -1337;

$( document ).keydown(function(e) {
    last_key = e.which;
});
