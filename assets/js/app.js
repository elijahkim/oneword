// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import css from "../css/app.css"
import "mdn-polyfills/CustomEvent"
import "mdn-polyfills/String.prototype.startsWith"
import "mdn-polyfills/Array.from"
import "mdn-polyfills/NodeList.prototype.forEach"
import "mdn-polyfills/Element.prototype.closest"
import "mdn-polyfills/Element.prototype.matches"
import "mdn-polyfills/Node.prototype.remove"
import "child-replace-with-polyfill"
import "url-search-params-polyfill"
import "formdata-polyfill"
import "classlist-polyfill"
import "@webcomponents/template"
import "shim-keyboard-event-key"
import * as _ from "lodash"

// webpack automatically bundles all modules in your
// entry points. Those entry points can be configured
// in "webpack.config.js".
//
// Import dependencies
//
import "phoenix_html"

// Import local files
//
// Local files can be imported directly using relative paths, for example:
// import socket from "./socket"

import {Socket} from "phoenix"
import LiveSocket from "phoenix_live_view"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}});
liveSocket.connect()

const canvas = document.getElementById('canvas');

async function createPeer() {
  // const configuration = {'iceServers': [{'urls': 'stun:stun.l.google.com:19302'}]}
  const configuration = {}
  const peerConnection = new RTCPeerConnection(configuration)

  const stream = await navigator.mediaDevices.getUserMedia({audio: true, video: false})

  stream.getTracks().forEach((track) => {
    peerConnection.addTrack(track)
  })

  const remoteStream = new MediaStream();
  const remoteVideo = document.querySelector('#remoteVideo');
  remoteVideo.vol = 100
  remoteVideo.srcObject = remoteStream;

  peerConnection.addEventListener('track', async (event) => {
    remoteStream.addTrack(event.track, remoteStream);
  });

  return peerConnection
}

async function createOffer(peer) {
  const offer = await peer.createOffer()
  peer.setLocalDescription(offer)
  return offer
}

if (canvas) {
  let users = {};
  let connections = {};
  const ctx = canvas.getContext('2d');
  const uuid = create_UUID()

  let socket = new Socket("/socket", {params: {user_id: uuid}})
  socket.connect()

  let channel = socket.channel("users")
  let myChannel = socket.channel(`users:${uuid}`)

  myChannel.on("new_offer", async msg => {
    console.log("NEW OFFER")
    const {from, offer} = msg
    console.log(from)
    console.log(offer)

    let peerConnection = await createPeer()
    console.log(peerConnection)
    await peerConnection.setRemoteDescription(new RTCSessionDescription(offer))

    const answer = await peerConnection.createAnswer()
    console.log(answer)
    await peerConnection.setLocalDescription(answer)

    console.log("sending answer")
    myChannel.push("send_answer", {answer, to: from})
  })

  myChannel.on("answer", async msg => {
    console.log("ANSWER")
    const {from, answer} = msg
    console.log(from)
    console.log(answer)

    const remoteDesc = await new RTCSessionDescription(answer);
    const connection = connections[from]
    await connection.setRemoteDescription(remoteDesc);

    console.log("DONE")
    console.log(connection)
  })

  channel.on("presence_state", async msg => {
    users = _.assign(users, _.mapValues(msg, (join) => join.metas[0].position))
    const userIds = Object.keys(users).filter((item) => item !== uuid)

    console.log("PRESENSCE STATE USER IDS", userIds)
    console.log("ME", uuid)

    userIds.forEach(async (id) => {
      const peer = await createPeer()
      const offer = await createOffer(peer)

      connections[id] = peer
      console.log("sending offer")
      channel.push(`send_offer:${id}`, offer)
    })

    _.forEach(users, (position) => {
      if (position) {
        drawCircle(position, ctx)
      }
    })
  })

  channel.on("presence_diff", msg => {
    canvas.width = canvas.width
    users = _.omit(users, _.keys(msg.leaves))
    users = _.assign(users, _.mapValues(msg.joins, (join) => join.metas[0].position))

    _.forEach(users, (position) => {
      if (position) {
        drawCircle(position, ctx)
      }
    })
  })

  channel.join()
    .receive("ok", ({messages}) => console.log("catching up", messages) )
    .receive("error", ({reason}) => console.log("failed join", reason) )
    .receive("timeout", () => console.log("Networking issue. Still waiting..."))

  myChannel.join()
    .receive("ok", ({messages}) => console.log("catching up", messages) )
    .receive("error", ({reason}) => console.log("failed join", reason) )
    .receive("timeout", () => console.log("Networking issue. Still waiting..."))

  canvas.addEventListener('click', (e) => {
    const rect = canvas.getBoundingClientRect()
    const x = event.clientX - rect.left
    const y = event.clientY - rect.top
    const pos = { x, y }

    channel.push("new_location", pos, 10000)
  })
}

function drawCircle({x, y}, ctx) {
  ctx.beginPath();
  ctx.arc(x, y, 10, 0, 2 * Math.PI);
  ctx.stroke();
}

function create_UUID(){
  let dt = new Date().getTime();
  const uuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
      var r = (dt + Math.random()*16)%16 | 0;
      dt = Math.floor(dt/16);
      return (c=='x' ? r :(r&0x3|0x8)).toString(16);
  });
  return uuid;
}
