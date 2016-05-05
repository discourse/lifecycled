package main

import (
	"os"

	"github.com/alecthomas/kingpin"
	"github.com/apex/log"
	"github.com/apex/log/handlers/text"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/autoscaling"
	"github.com/lox/lifecycled"
)

const (
	simulateQueue = "simulate"
)

var (
	verbose    = kingpin.Flag("verbose", "Verbose mode.").Short('v').Bool()
	instanceID = kingpin.Flag("instanceid", "The instance id to look for").String()
	sqsQueue   = kingpin.Flag("queue", "The sqs queue to consume").Required().String()
	handler    = kingpin.Flag("handler", "The script to invoke to handle events").Required().File()
	debug      = kingpin.Flag("debug", "Show debugging info").Bool()
)

func main() {
	log.SetHandler(text.New(os.Stderr))
	kingpin.CommandLine.DefaultEnvars()
	kingpin.Parse()

	var queue lifecycled.Queue

	// provide a simulated queue for testing
	if *sqsQueue == simulateQueue {
		queue = lifecycled.NewSimulatedQueue(*instanceID)
	} else {
		queue = lifecycled.NewSQSQueue(*sqsQueue, *instanceID)
	}

	if *debug {
		log.SetLevel(log.DebugLevel)
	}

	signals := make(chan os.Signal)
	// signal.Notify(signals, os.Interrupt, os.Kill)

	daemon := lifecycled.Daemon{
		Queue:       queue,
		AutoScaling: autoscaling.New(session.New()),
		Handler:     *handler,
		Signals:     signals,
	}

	err := daemon.Start()
	if err != nil {
		log.Error(err.Error())
		os.Exit(1)
	}
}
