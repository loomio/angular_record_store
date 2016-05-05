module.exports = (karma) ->
  karma.set
    frameworks: [ 'browserify', 'jasmine' ]
    files: ['test/*.coffee']
    preprocessors:
      'test/*.coffee': [ 'browserify' ]

    reporters: [ 'dots' ]
    logLevel: 'LOG_DEBUG'
    singleRun: true
    autoWatch: false

    browsers: ['chrome_no_sandbox']
    customLaunchers:
      chrome_no_sandbox:
        base: 'Chrome'
        flags: ['--no-sandbox']

    browserify:
      debug: true
