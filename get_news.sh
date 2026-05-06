#!/usr/bin/env bash

# Usage:
#   get_news.sh
#
# This script reads the latest headlines from various sources.

# Stop on error
set -e

readable_date() {
	# Get day, month, and year
	day=$(date +%d)
	month=$(date +%B)
	year=$(date +%Y)
	weekday=$(date +%A)

	# Determine the suffix for the day
	if (( day == 1 || day == 21 || day == 31 )); then
	  suffix="st"
	elif (( day == 2 || day == 22 )); then
	  suffix="nd"
	elif (( day == 3 || day == 23 )); then
	  suffix="rd"
	else
	  suffix="th"
	fi

	# Remove leading zero from day if present
	day=$(echo $day | sed 's/^0*//')

	# Combine to form friendly date
	echo "$weekday the $day$suffix of $month, $year."
}

echo "Hello and welcome to the rapid-fire headline segment on Whisper Radio. The date is $(readable_date). Let's read some headlines."
echo "Latest accession in someodd's gopher library: $(./get_feed.sh 'gopher://gopher.someodd.zip:70/0/library/catalog/feed.xml' | sed 's/\.md$//'). "
echo "..."
echo "CGTN world news: $(./get_feed.sh 'https://www.cgtn.com/subscribe/rss/section/world.xml'). "
echo "..."
echo "New York Times headline reads: $(./get_feed.sh 'https://rss.nytimes.com/services/xml/rss/nyt/World.xml'). "
echo "..."
echo "And now a Planet Debian update: $(./get_feed.sh 'https://planet.debian.org/rss20.xml'). "
echo "This concludes the headlines segment. Stay tuned for more content."