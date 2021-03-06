assert        = require 'assert'
child_process = require 'child_process'
fs            = require 'fs'
path          = require 'path'
os            = require 'os'

describe 'node feature', ->
  fixtures = path.join __dirname, 'fixtures'

  describe 'child_process', ->
    describe 'child_process.fork', ->
      it 'works in current process', (done) ->
        child = child_process.fork path.join(fixtures, 'module', 'ping.js')
        child.on 'message', (msg) ->
          assert.equal msg, 'message'
          done()
        child.send 'message'

      it 'works in forked process', (done) ->
        child = child_process.fork path.join(fixtures, 'module', 'fork_ping.js')
        child.on 'message', (msg) ->
          assert.equal msg, 'message'
          done()
        child.send 'message'

      it 'works in forked process when options.env is specifed', (done) ->
        child = child_process.fork path.join(fixtures, 'module', 'fork_ping.js'),
                                   [],
                                   path: process.env['PATH']
        child.on 'message', (msg) ->
          assert.equal msg, 'message'
          done()
        child.send 'message'

      it 'works in browser process', (done) ->
        fork = require('remote').require('child_process').fork
        child = fork path.join(fixtures, 'module', 'ping.js')
        child.on 'message', (msg) ->
          assert.equal msg, 'message'
          done()
        child.send 'message'

  describe 'contexts', ->
    describe 'setTimeout in fs callback', ->
      it 'does not crash', (done) ->
        fs.readFile __filename, ->
          setTimeout done, 0

    describe 'setTimeout in pure uv callback', ->
      it 'does not crash', (done) ->
        process.scheduleCallback ->
          setTimeout done, 0

    describe 'throw error in node context', ->
      it 'gets caught', (done) ->
        error = new Error('boo!')
        lsts = process.listeners 'uncaughtException'
        process.removeAllListeners 'uncaughtException'
        process.on 'uncaughtException', (err) ->
          process.removeAllListeners 'uncaughtException'
          for lst in lsts
            process.on 'uncaughtException', lst
          done()
        fs.readFile __filename, ->
          throw error

  describe 'message loop', ->
    describe 'process.nextTick', ->
      it 'emits the callback', (done) ->
        process.nextTick done

      it 'works in nested calls', (done) ->
        process.nextTick ->
          process.nextTick ->
            process.nextTick done

    describe 'setImmediate', ->
      it 'emits the callback', (done) ->
        setImmediate done

      it 'works in nested calls', (done) ->
        setImmediate ->
          setImmediate ->
            setImmediate done

  describe 'net.connect', ->
    it 'emit error when connect to a socket path without listeners', (done) ->
      return done() if process.platform is 'win32'

      socketPath = path.join os.tmpdir(), 'atom-shell-test.sock'
      script = path.join(fixtures, 'module', 'create_socket.js')
      child = child_process.fork script, [socketPath]
      child.on 'exit', ->
        client = require('net').connect socketPath
        client.on 'error', (error) ->
          assert.equal error.code, 'ECONNREFUSED'
          done()
