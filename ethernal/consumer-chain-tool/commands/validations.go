package commands

import (
	"fmt"
	"os"
	"regexp"
	"strconv"
	"time"
)

var (
	reDnmString = `[a-zA-Z][a-zA-Z0-9/-]{2,127}`
	reDecAmt    = `[[:digit:]]+(?:\.[[:digit:]]+)?|\.[[:digit:]]+`
	reSpc       = `[[:space:]]*`
	reDecCoin   = regexp.MustCompile(fmt.Sprintf(`^(%s)%s(%s)$`, reDecAmt, reSpc, reDnmString))
)

func IsValidInputPath(pathStr string) bool {
	fileInfo, err := os.Stat(pathStr)

	return err == nil && fileInfo.IsDir()
}

func IsValidOutputPath(pathStr string) bool {
	return os.MkdirAll(pathStr, os.ModePerm) == nil
}

// TODO: should we use regular expressions in this check?
func IsValidString(input string) bool {
	return input != ""
}

func isPositiveInt(input string) bool {
	revHeight, err := strconv.Atoi(input)
	if err != nil || revHeight < 0 {
		return false
	}

	return true
}

func IsValidDateTime(input string) (time.Time, bool) {
	t, err := time.Parse(time.RFC3339Nano, input)
	if err != nil {
		return time.Now().UTC(), false
	}

	return t, true
}

// TODO: basic validation, expects only one coin and its amount
func IsValidDeposit(input string) bool {
	matches := reDecCoin.FindStringSubmatch(input)
	if matches == nil || len(matches) != 3 {
		return false
	}

	return true
}

func IsValidFilePath(path string) bool {
	fileInfo, err := os.Stat(path)
	return err == nil && fileInfo.Mode().IsRegular()
}
