package main

import (
	"bufio"
	"fmt"
	"os"
	"strings"
)

var push, pop map[string]uint64

func main() {
	scanner := bufio.NewScanner(os.Stdin)
	push = make(map[string]uint64)
	pop = make(map[string]uint64)

	for {
		// Scans a line from Stdin(Console)
		scanner.Scan()
		// Holds the string that scanned
		text := scanner.Text()
		if len(text) != 0 {
			commands := strings.Fields(text)
			if commands[0] == "pushq" {
				push[commands[1]] += 1
			}
			if commands[0] == "popq" {
				pop[commands[1]] += 1
			}
		} else {
			break
		}
	}

	fmt.Println("register,", "push,", "pop")

	var names = make(map[string]bool)
	for name := range push {
		names[name] = true
	}
	for name := range pop {
		names[name] = true
	}
	for name := range names {
		fmt.Println(name, ",", push[name], ",", pop[name])
	}
}
