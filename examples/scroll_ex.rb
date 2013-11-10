#!/usr/bin/env ruby
# NOTE: This example/demo might be weird/bad-formatted/ugly.
#       I'm currently refactoring all demos/examples from the
#       original 'tawny-cdk' repository and THIS FILE wasn't
#       touched yet.
#       I suggest you go look for files without this notice.
#

require_relative 'example'

class ScrollExample < CLIExample
  @@count = 0
  def ScrollExample.newLabel(prefix)
    result = "%s%d" % [prefix, @@count]
    @@count += 1
    return result
  end

  def ScrollExample.parse_opts(opts, params)
    opts.banner = 'Usage: scroll_ex.rb [options]'

    # default values
    params.box = true
    params.shadow = false
    params.x_value = RNDK::CENTER
    params.y_value = RNDK::CENTER
    params.h_value = 10
    params.w_value = 50
    params.c = false
    params.spos = RNDK::RIGHT
    params.title = "<C></5>Pick a file"

    super(opts, params)

    opts.on('-c', 'create the data after the widget') do
      params.c = true
    end

    opts.on('-s SCROLL_POS', OptionParser::DecimalInteger,
        'location for the scrollbar') do |spos|
      params.spos = spos
    end

    opts.on('-t TITLE', String, 'title for the widget') do |title|
      params.title = title
    end
  end

  # This program demonstrates the Rndk scrolling list widget.
  #
  # Options (in addition to normal CLI parameters):
  #   -c      create the data after the widget
  #   -s SPOS location for the scrollbar
  #   -t TEXT title for the widget
  def ScrollExample.main
    # Declare variables.
    temp = ''

    params = parse(ARGV)

    # Set up RNDK
    curses_win = Ncurses.initscr
    rndkscreen = RNDK::Screen.new(curses_win)

    # Set up RNDK colors
    RNDK::Draw.initRNDKColor

    # Use the current directory list to fill the radio list
    item = []
    count = RNDK.getDirectoryContents(".", item)

    # Create the scrolling list.
    scroll_list = RNDK::SCROLL.new(rndkscreen,
        params.x_value, params.y_value, params.spos,
        params.h_value, params.w_value, params.title,
        if params.c then nil else item end,
        if params.c then 0 else count end,
        true, Ncurses::A_REVERSE, params.box, params.shadow)

    if scroll_list.nil?
      rndkscreen.destroyRNDKScreen
      RNDK::Screen.end_rndk

      puts "Cannot make scrolling list.  Is the window too small?"
      exit #EXIT_FAILURE
    end

    if params.c
      scroll_list.setItems(item, count, true)
    end

    addItemCB = lambda do |type, object, client_data, input|
      object.addItem(ScrollExample.newLabel("add"))
      object.screen.refresh
      return true
    end

    insItemCB = lambda do |type, object, client_data, input|
      object.insertItem(ScrollExample.newLabel("insert"))
      object.screen.refresh
      return true
    end

    delItemCB = lambda do |type, object, client_data, input|
      object.deleteItem(object.getCurrentItem)
      object.screen.refresh
      return true
    end

    scroll_list.bind(:SCROLL, 'a', addItemCB, nil)
    scroll_list.bind(:SCROLL, 'i', insItemCB, nil);
    scroll_list.bind(:SCROLL, 'd', delItemCB, nil);

    # Activate the scrolling list.

    selection = scroll_list.activate('')

    # Determine how the widget was exited
    if scroll_list.exit_type == :ESCAPE_HIT
      msg = ['<C>You hit escape. No file selected']
      msg << ''
      msg << '<C>Press any key to continue.'
      rndkscreen.popupLabel(msg, 3)
    elsif scroll_list.exit_type == :NORMAL
      the_item = RNDK.chtype2Char(scroll_list.item[selection])
      msg = ['<C>You selected the following file',
          "<C>%.*s" % [236, the_item],  # FIXME magic number
          "<C>Press any key to continue."
      ]
      rndkscreen.popupLabel(msg, 3);
      #freeChar (theItem);
    end

    # Clean up.
    # RNDKfreeStrings (item);
    scroll_list.destroy
    rndkscreen.destroy
    RNDK::Screen.end_rndk
    exit #EXIT_SUCCESS
  end
end

ScrollExample.main
