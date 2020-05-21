import * as _ from "lodash"
import {Socket} from "phoenix"
import socket from "./socket"

export function createChannel(id) {
  let channel = socket.channel(`users:${id}`)
}
