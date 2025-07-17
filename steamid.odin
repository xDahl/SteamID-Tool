/*
	MIT License

	Copyright (c) 2025 xDahl

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
*/

package main

import "core:c/libc"
import "core:os"
import "core:fmt"
import "core:time"


PrintFlags :: enum {
	LABEL,
	AID_DEC,
	AID_HEX,
	ID2,
	ID3,
	ID64,
	LINK,
	DATE
}

PrintFlagsDefault :: bit_set[PrintFlags]{.LABEL,.AID_DEC,.ID2,.ID3,.ID64,.LINK,.DATE}

main :: proc()
{
	using fmt

	month := [?]string{
		"January", "Febuary", "March", "April",
		"May", "June", "July", "August",
		"September", "October", "November", "December"
	}

	// Simple hack to enable VT100 parsing on Windows.
	when ODIN_OS == .Windows {
		libc.system("")
	}

	print_flags := PrintFlagsDefault

	println("\e[32m-------------=======<[ \e[7m SteamID Tools \e[27m ]>=======-------------")
	println("\e[36mTo change printing mode, type '!' followed by a list of flags:")
	println(" l\tPrint Labeling.")
	println(" a\tPrint AccountID    (      Decimal      ).")
	println(" A\tPrint AccountID    (    Hexadecimal    ).")
	println(" 2\tPrint SteamID2     ( STEAM_1:0:xxxxxx  ).")
	println(" 3\tPrint SteamID3     (    [U:1:xxxxxx]   ).")
	println(" 6/4\tPrint SteamID64    ( 76561197960265728 ).")
	println(" u\tPrint Profile URL.")
	println(" d\tPrint \e[31;1mESTIMATED\e[m\e[36m account creation date.")

	{
		y, m, _, _ := account_date(data_set[len(data_set)-2])
		printf("         \e[33m[ Data-Set last dated to: %s %d ]\n", month[m], y)
		printf(" [ Dates estimations after this date are predictions! ]\e[m\n")
	}

	when ODIN_DEBUG {
		avg := 0
		cnt := 0
		for i in 0..<3 {
			avg += data_set[len(data_set)-1-i] - data_set[len(data_set)-2-i]
			cnt += 1
		}
		avg /= cnt

		fmt.printf("%d, // Prediction\n",
			data_set[len(data_set)-1] + avg)
	}

	buffer : [256]u8
	for {
		printf("\nEnter SteamID: ")
		len, _ := os.read(os.stdin, buffer[:])

		if buffer[0] == '!' {
			print_flags = parse_flags(buffer[1:len])
			continue
		}

		account_id, ok := parse_id(buffer[:len])
		if !ok {
			println("\e[31mError parsing SteamID!\e[m")
			continue
		}

		printf("\e[2A\e[J")
		if .AID_DEC in print_flags {
			if .LABEL in print_flags {
				printf("AccountID:     ")
			}
			printf("%d\n", account_id)
		}
		if .AID_HEX in print_flags {
			if .LABEL in print_flags {
				printf("AccountID Hex: ")
			}
			printf("%X\n", account_id)
		}
		if .ID2 in print_flags {
			if .LABEL in print_flags {
				printf("SteamID2:      ")
			}
			printf("STEAM_1:%d:%d\n", account_id & 1, account_id >> 1)
		}
		if .ID3 in print_flags {
			if .LABEL in print_flags {
				printf("SteamID3:      ")
			}
			printf("[U:1:%d]\n", account_id)
		}
		if .ID64 in print_flags {
			if .LABEL in print_flags {
				printf("SteamID64:     ")
			}
			printf("%d\n", account_id | (1 << 32) | (1 << 52) | (1 << 56))
		}
		if .LINK in print_flags {
			if .LABEL in print_flags {
				printf("Link:          ")
			}
			printf("https://steamcommunity.com/profiles/%d\n", account_id | (1 << 32) | (1 << 52) | (1 << 56))
		}
		if .DATE in print_flags {
			if .LABEL in print_flags {
				printf("Date:          ")
			}
			y, m, d, a := account_date(account_id)
			printf("%d %s %d, Days old: %d\n",
				y, month[m], d, a)
		}
	}
}

parse_id :: proc(b : []u8) -> (aid : int, ok : bool)
{
	non_whitespace :: proc(b : []u8) -> int
	{
		for v, i in b[:] {
			if v != ' ' && v != '\t' {
				return i
			}
		}
		return 0
	}

	parse_int :: proc(b : []u8) -> (num : int)
	{
		for v in b[:] {
			switch v {
			case '0'..='9': num = num * 10 + int(v - '0')
			}
		}

		return num & 0xFFFFFFFF
	}

	parse_hex :: proc(b : []u8) -> (num : int)
	{
		for v in b[:] {
			switch v {
			case '0'..='9': num = num * 16 + int(v - '0')
			case 'a'..='f': num = num * 16 + int(v - 'a') + 10
			case 'A'..='F': num = num * 16 + int(v - 'A') + 10
			case: break
			}
		}

		return num & 0xFFFFFFFF
	}

	idx := non_whitespace(b[:])

	// Basic (bad) parsing, guessing the format typed by the user.
	switch b[idx] {
	case '[', 'U', ':': // SteamID3  [U:1:201]
		col : int
		for ; idx < len(b); idx += 1 {
			if b[idx] == ':' {
				col += 1
			}
			if col >= 2 {
				aid = parse_int(b[idx+1:])
				break
			}
		}

	case 'S', 'T', 'E', 'A', 'M': // SteamID2  STEAM_0:1:100
		for ; idx < len(b); idx += 1 {
			if b[idx] == ':' {
				break
			}
		}
		aid = cast(int)(b[idx+1] - '0') + 2 * parse_int(b[idx+3:])

	case 'x', 'X': // Hex string.
		aid = parse_hex(b[idx+1:])

	case 'h', 'w', 's': // URL (steamcommunity / http).
		// increase idx to number part.
		for ; idx < len(b) && b[idx] != '7'; {
			idx += 1
		}
		fallthrough

	case: // ID64  76561197960265929
		aid = parse_int(b[idx:])
	}

	if aid == 0 { return 0, false }
	return aid, true
}

parse_flags :: proc(b : []u8) -> (fl : bit_set[PrintFlags])
{
	for v in b[:] {
		switch v {
		case 'l': fl += {.LABEL}
		case 'a': fl += {.AID_DEC}
		case 'A': fl += {.AID_HEX}
		case '2': fl += {.ID2}
		case '3': fl += {.ID3}
		case '6', '4': fl += {.ID64}
		case 'u', 'U': fl += {.LINK}
		case 'd', 'D': fl += {.DATE}
		}
	}

	return card(fl) == 0 || fl == {.LABEL} ? PrintFlagsDefault : fl
}

// Returns an approximate date and age of an account.
account_date :: proc(accountid : int) -> (year, month, day, age : int)
{
	binary_search :: proc(id : int) -> int
	{
		l, m, r := 0, len(data_set)/2, len(data_set)-1

		for l <= r {
			if id == data_set[m] {
				return m
			} else if id > data_set[m] {
				l = m + 1
			} else {
				r = m - 1
			}
			m = l + (r - l) / 2
		}

		return m
	}

	range :: proc(a, b, t : int) -> f64
	{
		if t >= b { return 1.0 }
		if t <= a { return 0.0 }
		return cast(f64)(t-a) / cast(f64)(b-a)
	}

	lerp :: proc(a, b : int, f : f64) -> int
	{
		return cast(int)(cast(f64)a + cast(f64)(b - a) * f)
	}

	@(static) month_days := [12]int{
		31, 28, 31, 30, 31, 30,
		31, 31, 30, 31, 30, 31
	}

	index : int = ---
	if accountid >= data_set[len(data_set)-1] {
		index = len(data_set)-1
	} else {
		index = binary_search(accountid + 1)
	}

	start : int = ---
	unix  := f64((time.now()._nsec / 1e+9) / 86400) + 719542.5

	if index <= 9 {
		start = 10
		year, month = 2003, 8
	} else {
		start = 1
		year  = (index - 1) / 12 + 2003
		month = (index - 1) % 12
	}
	day = lerp(start, month_days[(index % 12)],
		range(data_set[index - 1], data_set[index], accountid))

	if index >= len(data_set) - 1 {
		age = 0
	} else {
		age = int(unix - (f64(day-1) + f64(month) * 30.4375 + f64(year) * 365.25))
	}

	return
}

data_set := [?]int{
	// Dummy values.
	0, // 2003 January
	0, // 2003 February
	0, // 2003 March
	0, // 2003 April
	0, // 2003 May
	0, // 2003 June
	0, // 2003 July
	0, // 2003 August
	0, // 1, // 2003 September
	1366023, // 2003 October
	2207562, // 2003 November
	2873741, // 2003 December

	3405727, // 2004 January
	3972589, // 2004 February
	4475784, // 2004 March
	5179886, // 2004 April
	5956267, // 2004 May
	6542337, // 2004 June
	7033739, // 2004 July
	7586813, // 2004 August
	8354508, // 2004 September
	8959424, // 2004 October
	9729026, // 2004 November
	11102513, // 2004 December

	12434276, // 2005 January
	13554274, // 2005 February
	14316272, // 2005 March
	14968286, // 2005 April
	15474375, // 2005 May
	15995690, // 2005 June
	16511777, // 2005 July
	17023379, // 2005 August
	17609375, // 2005 September
	18116275, // 2005 October
	18705532, // 2005 November
	19228642, // 2005 December

	19867768, // 2006 January
	20454055, // 2006 February
	21012820, // 2006 March
	21587022, // 2006 April
	22157844, // 2006 May
	22616755, // 2006 June
	23219814, // 2006 July
	23803808, // 2006 August
	24427885, // 2006 September
	24947989, // 2006 October
	25693138, // 2006 November
	26233246, // 2006 December

	26934313, // 2007 January
	27652531, // 2007 February
	28234273, // 2007 March
	28934272, // 2007 April
	29454331, // 2007 May
	30034272, // 2007 June
	30734273, // 2007 July
	31434272, // 2007 August
	32157031, // 2007 September
	32834273, // 2007 October
	33734272, // 2007 November
	34409281, // 2007 December

	35310181, // 2008 January
	36144272, // 2008 February
	36734272, // 2008 March
	37562431, // 2008 April
	38234272, // 2008 May
	38894272, // 2008 June
	39364231, // 2008 July
	40134272, // 2008 August
	40715581, // 2008 September
	41434272, // 2008 October
	42066931, // 2008 November
	43418281, // 2008 December

	44494272, // 2009 January
	45670531, // 2009 February
	47021881, // 2009 March
	48373231, // 2009 April
	49274131, // 2009 May
	50434272, // 2009 June
	51334272, // 2009 July
	52234272, // 2009 August
	53134273, // 2009 September
	54134272, // 2009 October
	55129981, // 2009 November
	57382231, // 2009 December

	59184031, // 2010 January
	60535381, // 2010 February
	61886731, // 2010 March
	63238081, // 2010 April
	64334272, // 2010 May
	65940781, // 2010 June
	67034272, // 2010 July
	68193031, // 2010 August
	69934272, // 2010 September
	71346181, // 2010 October
	72697531, // 2010 November
	74499331, // 2010 December

	76301131, // 2011 January
	77652481, // 2011 February
	78553381, // 2011 March
	79904731, // 2011 April
	81256081, // 2011 May
	82607431, // 2011 June
	84409231, // 2011 July
	86211031, // 2011 August
	88012831, // 2011 September
	89814631, // 2011 October
	91366872, // 2011 November
	93418231, // 2011 December

	96120931, // 2012 January
	97922731, // 2012 February
	99724531, // 2012 March
	101075881, // 2012 April
	102877681, // 2012 May
	104679481, // 2012 June
	106030831, // 2012 July
	108283081, // 2012 August
	110535331, // 2012 September
	112787581, // 2012 October
	114589381, // 2012 November
	117034272, // 2012 December

	119994781, // 2013 January
	122697481, // 2013 February
	124949731, // 2013 March
	127652431, // 2013 April
	130355131, // 2013 May
	133057831, // 2013 June
	136210981, // 2013 July
	140715481, // 2013 August
	145219981, // 2013 September
	149274031, // 2013 October
	152877631, // 2013 November
	156481231, // 2013 December

	160985731, // 2014 January
	165039781, // 2014 February
	168192931, // 2014 March
	171796531, // 2014 April
	175400131, // 2014 May
	178553281, // 2014 June
	183057781, // 2014 July
	187562281, // 2014 August
	192517231, // 2014 September
	196571281, // 2014 October
	201075781, // 2014 November
	206030731, // 2014 December

	211436131, // 2015 January
	216841531, // 2015 February
	222246931, // 2015 March
	229003681, // 2015 April
	234859531, // 2015 May
	239364031, // 2015 June
	244769431, // 2015 July
	250625281, // 2015 August
	255129781, // 2015 September
	292967581, // 2015 October
	297922531, // 2015 November
	303778381, // 2015 December

	313688281, // 2016 January
	320895481, // 2016 February
	327201781, // 2016 March
	334859431, // 2016 April
	342517081, // 2016 May
	347922481, // 2016 June
	355580131, // 2016 July
	361435981, // 2016 August
	368192731, // 2016 September
	374949481, // 2016 October
	381706231, // 2016 November
	387562081, // 2016 December

	397019273, // 2017 January
	403327831, // 2017 February
	409634131, // 2017 March
	416390881, // 2017 April
	425399881, // 2017 May
	432607081, // 2017 June
	440715181, // 2017 July
	448823281, // 2017 August
	457381831, // 2017 September
	467742181, // 2017 October
	480354781, // 2017 November
	489363781, // 2017 December

	841615681, // 2018 January
	850624681, // 2018 February
	856930981, // 2018 March
	866840881, // 2018 April
	873597631, // 2018 May
	879003031, // 2018 June
	884858880, // 2018 July
	891165181, // 2018 August
	897021031, // 2018 September
	902876881, // 2018 October
	908282281, // 2018 November
	913237231, // 2018 December

	922246231, // 2019 January
	934858831, // 2019 February
	969092892, // 2019 March
	987561481, // 2019 April
	1001525431, // 2019 May
	1007381281, // 2019 June
	1014138031, // 2019 July
	1021345231, // 2019 August
	1027651531, // 2019 September
	1033957831, // 2019 October
	1040654272, // 2019 November
	1047020881, // 2019 December

	1055579372, // 2020 January
	1063237081, // 2020 February
	1069993831, // 2020 March
	1081705531, // 2020 April
	1093734271, // 2020 May
	1102426231, // 2020 June
	1110534331, // 2020 July
	1118640273, // 2020 August
	1127200981, // 2020 September
	1134858631, // 2020 October
	1142966731, // 2020 November
	1152426181, // 2020 December

	1165038372, // 2021 January
	1175849581, // 2021 February
	1186659272, // 2021 March
	1197020731, // 2021 April
	1206029731, // 2021 May
	1215939631, // 2021 June
	1225399081, // 2021 July
	1234858531, // 2021 August
	1243417081, // 2021 September
	1251514272, // 2021 October
	1257831481, // 2021 November
	1264137781, // 2021 December

	1271344981, // 2022 January
	1279453081, // 2022 February
	1287561181, // 2022 March
	1300173273, // 2022 April
	1315038631, // 2022 May
	1349132775, // 2022 June
	1401975481, // 2022 July
	1419543031, // 2022 August
	1428096272, // 2022 September
	1443416772, // 2022 October
	1465939381, // 2022 November
	1480353781, // 2022 December

	1506479881, // 2023 January
	1515038431, // 2023 February
	1522696081, // 2023 March
	1531254631, // 2023 April
	1541164531, // 2023 May
	1550834272, // 2023 June
	1562164273, // 2023 July
	1572800007, // 2023 August
	1586859822, // 2023 September
	1597980840, // 2023 October
	1607111101, // 2023 November
	1616600000, // 2023 December

	1633600000, // 2024 January
	1668200000, // 2024 February
	1687000000, // 2024 March
	1701500000, // 2024 April
	1721005000, // 2024 May
	1737300006, // 2024 June
	1769200017, // 2024 July
	1792650132, // 2024 August
	1808300015, // 2024 September
	1826970000, // 2024 October
	1838534272, // 2024 November
	1845940000, // 2024 December

	1853307000, // 2025 January
	1862090000, // 2025 February
	1871100000, // 2025 March
	1881400011, // 2025 April
	1891050002, // 2025 May
	1901350013, // 2025 June
	1911250007, // 2025 July

	1921200005, // Prediction
}
