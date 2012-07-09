#!/usr/bin/awk -f

function min(arr,    minval, i) {
	minval = INFINITY
	for (i in arr) {
		if (arr[i] < minval) {
			minval = arr[i]
		}
	}
	return minval
}

function min_index(arr,    idx, i) {
	idx = INFINITY
	for (i in arr) {
		if (i < idx) {
			idx = i
		}
	}
	return idx
}

function max_index(arr,    idx, i) {
	idx = -INFINITY
	for (i in arr) {
		if (i > idx) {
			idx = i
		}
	}
	return idx
}

function sum(arr,    sumval) {
	sumval = 0
	for (i in arr) {
		sumval += arr[i]
	}
	return sumval
}

function join(arr, sep,    i, result) {
	if (sep) ; else { sep = "" }

	result = ""

	if (1 in arr) {
		sub(/$/, arr[1], result)
	}
	i = 2
	while (i in arr) {
		sub(/$/, sep, result)
		sub(/$/, arr[i], result)

		++i
	}

	return result
}

function sortn(arr,    cmd, tmp, tmpfile, i) {
	"mktemp -t freqd" | getline
	tmpfile = $1

	tmp = join(arr, "\n")
	print tmp >tmpfile

	cmd = "sort -n " tmpfile

	i = 1
	while (cmd | getline == 1) {
		arr[i] = 0 + $1
		++i
	}
	close(cmd)

	system("rm " tmpfile)
}

function getidles(result,    i, flag) {
	i = 1
	flag = 0
	for (;;) {
		"top -P -d infinity -s 1 0" | getline
		if (/^CPU [0-9]+:/) {
			flag = 1
			result[i] = 0 + $11
			++i
		} else if (flag) {
			break
		}
	}
}

function getfreq(    cmd) {
	cmd = "sysctl dev.cpu.0.freq"
	cmd | getline
	close(cmd)

	return 0 + $2
}

function getfreqlist(    cmd, result, tmp, i) {
	cmd = "sysctl dev.cpu.0.freq_levels"
	cmd | getline
	close(cmd)

	split($0, tmp)

	result = ""

	i = 2
	while (i in tmp) {
		sub(/\/.*/, "", tmp[i])
		sub(/$/, tmp[i], result)
		sub(/$/, " ", result)

		i += 1
	}

	sub(/ $/, "", result)
	return result
}

function setfreq(freq) {
	#system("sudo sysctl dev.cpu.0.freq=" freq)
	print freq
}

BEGIN {
	INFINITY = 1E+300 * 1E+300

	split(getfreqlist(), freqlist)
	for (i in freqlist) {
		freqlist[i] += 0
	}
	sortn(freqlist)

	low = min_index(freqlist)
	high = max_index(freqlist)

	current_freq = getfreq()

	for (i in freqlist) {
		if (freqlist[i] == current_freq) {
			current = i
		}
	}

	getidles(idles)
	load[2] = (100.0 - min(idles)) / 100.0

	getidles(idles)
	load[1] = (100.0 - min(idles)) / 100.0

	flag = 0
	for (;;) {
		load[3] = load[2] ; load[2] = load[1]

		getidles(idles)
		load[1] = (100.0 - min(idles)) / 100.0

		load_now = load[1]
		load_3 = sum(load) / 3.0

		#printf("%d %f %f\n", freqlist[current], load_now, load_3) >"/dev/stderr"

		if (flag == 1) {
			flag = 0
		} else {
			if ((current > low) && (load_3 < 0.4) && (load_now < 0.4)) {
				--current
				setfreq(freqlist[current])

				flag = 1
			}
		}

		if ((current < high) && (load_now > 0.8)) {
			++current
			setfreq(freqlist[current])

			flag = 1
		}
	}
}
