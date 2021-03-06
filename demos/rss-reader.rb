#!/usr/bin/env ruby
#
# A simple RSS reader.
# It receives a feed address as an argument, defaulting to the
# Ruby Language feed if not provided.
#
# When an item is selected, it's content pops-up.
#
require 'rss'
require 'open-uri'
require 'rndk/label'
require 'rndk/scroll'

DEFAULT_URL = 'https://www.ruby-lang.org/en/feeds/news.rss'

begin
  # which feed
  url = DEFAULT_URL
  url = ARGV.first if ARGV.first

  # retrieving things
  puts 'Fetching feeds...'
  feed = RSS::Parser.parse (open url)

  # starting RNDK
  screen = RNDK::Screen.new
  RNDK::Color.init

  # building label
  title = ["<C></77>#{feed.channel.title}",
           "</76>Press ESC to quit"]

  label = RNDK::Label.new(screen, {
                            :x => RNDK::CENTER,
                            :y => RNDK::TOP,
                            :title => "</77>#{feed.channel.title}"
                          })

  # will show the titles at scroll widget
  titles = []
  feed.items.each { |item| titles << item.title }

  # building scroll
  scroll = RNDK::Scroll.new(screen, {
                              :x => RNDK::CENTER,
                              :y => 4,
                              :width => RNDK::Screen.width/2,
                              :height => RNDK::Screen.height/2 - 5,
                              :title => "<C></77>Items",
                              :items => titles,
                              :numbers => true,
                              :highlight => RNDK::Color[:cyan],
                            })
  screen.refresh

  loop do
    scroll.activate

    # Scroll exited, thus the
    # user selected an item
    # or pressed ESC to get out
    if scroll.exit_type == :NORMAL

      # Getting current item's content
      index = scroll.current_item
      raw_message = feed.items[index].description

      # Removing '\n' at the end of all the lines.
      message = []
      raw_message.lines.each { |line| message << line.chomp }

      # Show current item's content on a pop-up
      screen.popup_label message

    # user pressed ESC - wants to quit
    elsif scroll.exit_type == :ESCAPE_HIT

      # good bye!
      RNDK::Screen.finish
      exit
    end
  end
end

