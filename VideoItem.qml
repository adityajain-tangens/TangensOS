import QtQuick
import QtMultimedia

// Plays one video file, as large as fits without stretching it. Click it to play or pause.
// Works inside a component or anywhere else.
Video {
    id: video

    // The video file to play, like file:///Users/me/clip.mp4
    property url file

    readonly property bool isPlaying: playbackState === MediaPlayer.PlayingState

    // How far it has played, in milliseconds, as y, like the scroll of items that scroll
    readonly property point scroll: Qt.point(0, position)
    // Where to start from once the file has loaded, in milliseconds
    property int startAt: 0
    function scrollTo(point) {
        startAt = point.y
    }

    source: file
    fillMode: VideoOutput.PreserveAspectFit
    // Show the first frame once the file has loaded, instead of a blank space
    onHasVideoChanged: if (hasVideo && !isPlaying) pause()
    // Then go to where it was left. Only once it's paused: before, the player ignores it.
    onPlaybackStateChanged: {
        if (playbackState !== MediaPlayer.PausedState || startAt <= 0)
            return
        seek(startAt)
        startAt = 0
    }

    TapHandler {
        onTapped: video.isPlaying ? video.pause() : video.play()
    }

    // A play sign while it's not playing
    Text {
        anchors.centerIn: parent
        visible: !video.isPlaying
        text: "▶"
        font.pixelSize: 48
        color: "white"
        style: Text.Outline
        styleColor: "#80000000"
    }

    // How far it has played, as a thin line along the bottom
    Rectangle {
        anchors.bottom: parent.bottom
        height: 3
        width: video.duration > 0 ? parent.width * video.position / video.duration : 0
        color: "#5b5bd6"
    }
}
