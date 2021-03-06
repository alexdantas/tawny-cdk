require 'rndk'

module RNDK

  # Pop-up calendar Widget.
  #
  # The Calendar Widget allows the user to traverse through
  # months/years using the cursor keys.
  #
  # ## Keybindings
  #
  # Left Arrow::  Moves the cursor to the previous day.
  # Right Arrow:: Moves the cursor to the next day.
  # Up Arrow::    Moves the cursor to the next week.
  # Down Arrow::  Moves the cursor to the previous week.
  # t::           Sets the calendar to the current date.
  # T::           Sets the calendar to the current date.
  # n::           Advances the calendar one month ahead.
  # N::           Advances the calendar six months ahead.
  # p::           Advances the calendar one month back.
  # P::           Advances the calendar six months back.
  # -::           Advances the calendar one year ahead.
  # +::           Advances the calendar one year back.
  # Enter::       Exits the widget and returns a value of
  #               time_t   which   represents   the   day
  #               selected at 1  second  after  midnight.
  #               This also sets the widget data `exit_type`
  #               to `:NORMAL`.
  # Tab::         Exits the widget and returns a value of
  #               time_t   which   represents   the   day
  #               selected at 1  second  after  midnight.
  #               This also sets the widget data `exit_type`
  #               to `:NORMAL`.
  # Escape::      Exits the widget and returns selected date
  #               This also sets the widget data `exit_type`
  #               to `:ESCAPE_HIT`.
  # Ctrl-L::      Refreshes the screen.
  #
  class Calendar < Widget

    attr_reader :day, :month, :year

    # First day of the week - Sunday is 0, Monday is 1, etc.
    attr_accessor :week_base

    MONTHS_OF_THE_YEAR = [
        'NULL',
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
    ]

    DAYS_OF_THE_MONTH = [
        -1,
        31,
        28,
        31,
        30,
        31,
        30,
        31,
        31,
        30,
        31,
        30,
        31,
    ]

    MAX_DAYS   = 32
    MAX_MONTHS = 13
    MAX_YEARS  = 140

    CALENDAR_LIMIT = (MAX_DAYS * MAX_MONTHS * MAX_YEARS)

    # Tells what day of the week the `month` starts on.
    def self.month_starting_weekday(year, month)
      return Time.mktime(year, month, 1, 10, 0, 0).wday
    end

    # Tells if `year` is a leap year.
    def self.leap_year? year
      result = false
      if year % 4 == 0
        if year % 100 == 0
          if year % 400 == 0
            result = true
          end
        else
          result = true
        end
      end
      result
    end

    # Returns how many days the `month`/`year` has.
    def self.days_in_month(year, month)
      month_length = DAYS_OF_THE_MONTH[month]

      if month == 2
        month_length += if Calendar.leap_year?(year)
                        then 1
                        else 0
                        end
      end

      month_length
    end

    # Creates a Calendar Widget.
    #
    # * `x` is the x position - can be an integer or
    #   `RNDK::LEFT`, `RNDK::RIGHT`, `RNDK::CENTER`.
    # * `y` is the y position - can be an integer or
    #   `RNDK::TOP`, `RNDK::BOTTOM`, `RNDK::CENTER`.
    # * `day`, `month` and `year` are integers on the
    #   format `dd`, `mm`, `yyyy`.
    # * `title` can be more than one line - just split them
    #   with `\n`s.
    # * `*_color` are specific colors.
    #
    # @note If `day`, `month` or `year` are zero, we'll use
    #       the current date for it (`Time.now.gmtime`).
    #       If all of them are 0, will use the complete date
    #       of today.
    def initialize(screen, config={})
      super()
      @widget_type = :calendar
      @supported_signals += [:before_input, :after_input]

      # This is UGLY AS HELL
      # But I don't have time to clean this up right now
      # (lots of widgets, you know)  :(
      x            = 0
      y            = 0
      title        = "calendar"
      day          = 0
      month        = 0
      year         = 0
      day_color   = 0
      month_color = 0
      year_color  = 0
      highlight    = RNDK::Color[:reverse]
      box          = true
      shadow       = false

      config.each do |key, val|
        x            = val if key == :x
        y            = val if key == :y
        title        = val if key == :title
        day          = val if key == :day
        month        = val if key == :month
        year         = val if key == :year
        day_color    = val if key == :day_color
        month_color  = val if key == :month_color
        year_color   = val if key == :year_color
        highlight    = val if key == :highlight
        box          = val if key == :box
        shadow       = val if key == :shadow
      end

      self.set_date(day, month, year)
      self.set_box box

      parent_width  = Ncurses.getmaxx(screen.window)
      parent_height = Ncurses.getmaxy(screen.window)

      box_width  = 24
      box_height = 11

      dayname = 'Su Mo Tu We Th Fr Sa '

      box_width   = self.set_title(title, box_width)
      box_height += @title_lines

      # Make sure we didn't extend beyond the dimensions
      # of the window.
      box_width = [box_width, parent_width].min
      box_height = [box_height, parent_height].min

      # Rejustify the x and y positions if we need to.
      xtmp = [x]
      ytmp = [y]
      RNDK.alignxy(screen.window, xtmp, ytmp, box_width, box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      # Create the calendar window.
      @win = Ncurses.newwin(box_height, box_width, ypos, xpos)

      # Is the window nil?
      if @win.nil?
        self.destroy
        return nil
      end
      Ncurses.keypad(@win, true)

      # Set some variables.
      @x_offset = (box_width - 20) / 2
      @field_width = box_width - 2 * (1 + @border_size)

      # Set months and day names
      @month_name = Calendar::MONTHS_OF_THE_YEAR.clone
      @day_name = dayname

      # Set the rest of the widget values.
      @screen = screen
      @parent = screen.window

      @xpos = xpos
      @ypos = ypos

      @width      = box_width
      @box_width  = box_width
      @box_height = box_height

      @day_color   = day_color
      @month_color = month_color
      @year_color  = year_color
      @highlight    = highlight

      @accepts_focus = true
      @input_window  = @win

      @week_base = 0

      @shadow     = shadow
      @shadow_win = nil

      @label_win = Ncurses.subwin(@win,
                                  1,
                                  @field_width,
                                  ypos + @title_lines + 1,
                                  xpos + 1 + @border_size)
      if @label_win.nil?
        self.destroy
        return nil
      end

      @field_win = Ncurses.subwin(@win,
                                  7,
                                  20,
                                  ypos + @title_lines + 3,
                                  xpos + @x_offset)
      if @field_win.nil?
        self.destroy
        return nil
      end

      # Mon Nov 11 18:54:40
      # another `set_box box` was here
      # apparently nothing fucked up, see if I can delete this

      @marker = [0] * Calendar::CALENDAR_LIMIT

      # If a shadow was requested, then create the shadow window.
      if shadow
        @shadow_win = Ncurses.newwin(box_height,
                                     box_width,
                                     ypos + 1,
                                     xpos + 1)
      end

      self.bind_key('t') { self.set_date(0, 0, 0)        }
      self.bind_key('T') { self.set_date(0, 0, 0)        }
      self.bind_key('n') { self.incrementCalendarMonth 1 }
      self.bind_key('p') { self.decrementCalendarMonth 1 }
      self.bind_key('N') { self.incrementCalendarMonth 6 }
      self.bind_key('P') { self.decrementCalendarMonth 6 }
      self.bind_key('-') { self.decrementCalendarYear 1  }
      self.bind_key('+') { self.incrementCalendarYear 1  }

      screen.register(:calendar, self)
    end

    # Sets `d`/`m`/`y` cell to have `value`.
    def setCalendarCell(d, m, y, value)
      @marker[Calendar.calendar_index(d, m, y)] = value
    end

    # Returns current value on cell `d`/`m`/`y`.
    def getCalendarCell(d, m, y)
      @marker[Calendar.calendar_index(d, m, y)]
    end

    # Activates the Widget, letting the user interact with it.
    #
    # `actions` is an Array of characters. If it's non-null,
    # will #inject each char on it into the Widget.
    #
    # @return The date or `nil` if something bad happened.
    def activate(actions=[])
      ret = nil
      self.draw

      if actions.nil? || actions.size == 0
        # Interacting with the user
        loop do
          input = self.getch

          # Inject the character into the widget.
          ret = self.inject input

          return ret if @exit_type != :EARLY_EXIT
        end

      else
        # Executing `actions`, one char at a time.
        actions.each do |action|
          ret = self.inject action

          return ret if @exit_type != :EARLY_EXIT
        end
      end
      ret
    end

    # @see Widget#inject
    def inject input
      pp_return = true
      ret       = nil
      complete  = false

      self.set_exit_type(0)
      self.draw_field

      # Check if there is a pre-process function to be called.
      keep_going = self.run_signal_binding(:before_input, input)

      if keep_going

        # Check a predefined binding
        if self.is_bound? input
          self.run_key_binding input

          ## FIXME What the heck? Missing method?
          #self.checkEarlyExit

          #complete = true

        else
          case input
          when Ncurses::KEY_UP,    RNDK::PREV
            self.decrementCalendarDay 7
          when Ncurses::KEY_DOWN,  RNDK::NEXT
            self.incrementCalendarDay 7
          when Ncurses::KEY_LEFT,  RNDK::BACKCHAR
            self.decrementCalendarDay 1
          when Ncurses::KEY_RIGHT, RNDK::FORCHAR
            self.incrementCalendarDay 1
          when Ncurses::KEY_NPAGE then self.incrementCalendarMonth 1
          when Ncurses::KEY_PPAGE then self.decrementCalendarMonth 1

          when Ncurses::KEY_HOME
            self.set_date(0, 0, 0)

          when RNDK::KEY_ESC
            self.set_exit_type input
            complete = true
          when Ncurses::ERR
            self.set_exit_type input
            complete = true
          when RNDK::KEY_TAB, RNDK::KEY_RETURN, Ncurses::KEY_ENTER
            self.set_exit_type input
            ret = self.get_current_time
            complete = true
          when RNDK::REFRESH
            @screen.erase
            @screen.refresh
          end
        end

        # Should we do a post-process?
        self.run_signal_binding(:after_input) if not complete
      end

      if !complete
        self.set_exit_type(0)
      end

      @result_data = ret
      return ret
    end

    # @see Widget#move
    def move(x, y, relative, refresh_flag)
      windows = [@win, @field_win, @label_win, @shadow_win]

      self.move_specific(x, y, relative, refresh_flag, windows, [])
    end

    # Draws the Widget on the Screen.
    #
    # If `box` is true, it is drawn with a box.
    def draw

      header_len = @day_name.size
      col_len = (6 + header_len) / 7

      # Is there a shadow?
      Draw.drawShadow(@shadow_win) unless @shadow_win.nil?

      # Box the widget if asked.
      draw_box @win if @box

      self.draw_title @win

      # Draw in the day-of-the-week header.
      (0...7).each do |col|
        src = col_len * ((col + (@week_base % 7)) % 7)
        dst = col_len * col
        Draw.writeChar(@win,
                       @x_offset + dst,
                       @title_lines + 2,
                       @day_name[src..-1],
                       RNDK::HORIZONTAL,
                       0,
                       col_len)
      end

      Ncurses.wrefresh @win
      self.draw_field
    end

    # Sets multiple attributes of the Widget.
    #
    # See Calendar#initialize.
    def set(config)
      # This is UGLY AS HELL
      # But I don't have time to clean this up right now
      # (lots of widgets, you know)  :(
      x            = 0
      y            = 0
      title        = "calendar"
      day          = 0
      month        = 0
      year         = 0
      day_color    = 0
      month_color  = 0
      year_color   = 0
      highlight    = RNDK::Color[:reverse]
      box          = false
      shadow       = false

      config.each do |key, val|
        x            = val if key == :x
        y            = val if key == :y
        title        = val if key == :title
        day          = val if key == :day
        month        = val if key == :month
        year         = val if key == :year
        day_color    = val if key == :day_color
        month_color  = val if key == :month_color
        year_color   = val if key == :year_color
        highlight    = val if key == :highlight
        box          = val if key == :box
        shadow       = val if key == :shadow
      end

      self.set_date(day, month, year)                if not day.zero? and month.zero? and year.zero?
      self.set_day_color(day_color)                if not day_color.zero?
      self.set_month_color(month_color)            if not month_color.zero?
      self.set_year_color(year_color)              if not year_color.zero?
      self.set_highlight(highlight)                  if highlight != RNDK::Color[:reverse]
      self.set_box(box)                              if box
      @box_width = self.set_title(title, @box_width) if title != "calendar"
    end

    # Sets the current date.
    #
    # @note If `day`, `month` or `year` are zero, we'll use
    #       the current date for it.
    #       If all of them are 0, will use the complete date
    #       of today.
    def set_date(day, month, year)

      # Get the current dates and set the default values for the
      # day/month/year values for the calendar
      date_info = Time.new.gmtime

      @day   = if day   == 0 then date_info.day   else day   end
      @month = if month == 0 then date_info.month else month end
      @year  = if year  == 0 then date_info.year  else year  end

      self.normalize_date

      # Get the start of the current month.
      @week_day = Calendar.month_starting_weekday(@year, @month)
    end

    # Returns the current date the calendar is displaying.
    #
    # @return An array with `[day, month, year]` numbers.
    def get_date
      [@day, @month, @year]
    end

    # Sets the appearance/color of the days.
    def set_day_color attribute
      @day_color = attribute
    end

    def get_day_color
      return @day_color
    end

    # Sets the appearance/color of the month name.
    def set_month_color attribute
      @month_color = attribute
    end

    def get_month_color
      return @month_color
    end

    # Sets the appearance/color of the year number.
    def set_year_color attribute
      @year_color = attribute
    end

    def get_year_color
      return @year_color
    end

    # Sets the attribute/color of the highlight bar of the scrolling list.
    def set_highlight highlight
      @highlight = highlight
    end

    def get_highlight
      return @highlight
    end

    # Sets the background attribute/color of the widget.
    def set_bg_color attrib
      Ncurses.wbkgd(@win, attrib)
      Ncurses.wbkgd(@field_win, attrib)
      Ncurses.wbkgd(@label_win, attrib) unless @label_win.nil?
    end

    # @see Widget#erase
    def erase
      return unless self.valid?

      RNDK.window_erase @label_win
      RNDK.window_erase @field_win
      RNDK.window_erase @win
      RNDK.window_erase @shadow_win
    end

    # @see Widget#destroy
    def destroy
      self.clean_title

      RNDK.window_delete @label_win
      RNDK.window_delete @field_win
      RNDK.window_delete @shadow_win
      RNDK.window_delete @win

      self.clean_bindings

      @screen.unregister self
    end

    # Sets a marker on a specific date.
    def set_marker(day, month, year, marker)
      year_index = Calendar.global_year_index(year)
      oldmarker = self.getMarker(day, month, year)

      # Check to see if a marker has not already been set
      if oldmarker != 0
        self.setCalendarCell(day, month, year_index, oldmarker | RNDK::Color[:blink])
      else
        self.setCalendarCell(day, month, year_index, marker)
      end
    end

    # Returns the marker on a specific date.
    def getMarker(day, month, year)
      result = 0
      year = Calendar.global_year_index(year)
      if @marker != 0
        result = self.getCalendarCell(day, month, year)
      end
      result
    end

    # Removes a marker from the Calendar.
    def removeMarker(day, month, year)
      year_index = Calendar.global_year_index(year)
      self.setCalendarCell(day, month, year_index, 0)
    end

    # Sets the month name.
    def setMonthNames(months)
      (1...[months.size, @month_name.size].min).each do |x|
        @month_name[x] = months[x]
      end
    end

    # Sets the names of the days of the week.
    #
    # `days` is a String listing the 2-character
    # abbreviations for the days.
    #
    # The default value is `"Su Mo Tu We Th Fr Sa"`
    #
    # "Su" (Sunday) is numbered zero internally, making it by default
    # the first day of the week. Set the `week_base` member of the
    # widget to select a different day.
    #
    # For example, Monday would be 1, Tuesday 2, etc.
    #
    def set_days_names days
      @day_name = days.clone
    end

    # Makes sure that the internal dates exist, capping
    # the values if too big/small.
    def normalize_date
      max = 1900 + MAX_YEARS - 1
      @year  = max if @year > max

      @year  = 1900 if @year  < 1900
      @month = 12   if @month > 12
      @month = 1    if @month < 1
      @day   = 1    if @day   < 1


      # Make sure the day given is within range of the month.
      month_length = Calendar.days_in_month(@year, @month)

      @day = month_length if @day > month_length
    end

    # This returns what day of the week the month starts on.
    def get_current_time
      # Determine the current time and determine if we are in DST.
      return Time.mktime(@year, @month, @day, 0, 0, 0).gmtime
    end

    def focus
      # Original: drawRNDKFscale(widget, ObjOf (widget)->box);
      self.draw
    end

    def unfocus
      # Original: drawRNDKFscale(widget, ObjOf (widget)->box);
      self.draw
    end

    # @see Widget#position
    def position
      super(@win)
    end

    protected

    # Returns the internal widget `year` index.
    # Minimum year is 1900.
    def self.global_year_index year
      return (year - 1900) if year >= 1900

      year
    end

    # Returns the specific internal index of `d`/`m`/`y`.
    def self.calendar_index(d, m, y)
      (y * Calendar::MAX_MONTHS + m) * Calendar::MAX_DAYS + d
    end

    # This increments the current day by the given value.
    def incrementCalendarDay(adjust)
      month_length = Calendar.days_in_month(@year, @month)

      # Make sure we adjust the day correctly.
      if adjust + @day > month_length
        # Have to increment the month by one.
        @day = @day + adjust - month_length
        self.incrementCalendarMonth(1)
      else
        @day += adjust
        self.draw_field
      end
    end

    # This decrements the current day by the given value.
    def decrementCalendarDay(adjust)
      # Make sure we adjust the day correctly.
      if @day - adjust < 1
        # Set the day according to the length of the month.
        if @month == 1
          # make sure we aren't going past the year limit.
          if @year == 1900
            mesg = [
                '<C></U>Error',
                'Can not go past the year 1900'
            ]
            RNDK.beep
            @screen.popup_label(mesg, 2)
            return
          end
          month_length = Calendar.days_in_month(@year - 1, 12)
        else
          month_length = Calendar.days_in_month(@year, @month - 1)
        end

        @day = month_length - (adjust - @day)

        # Have to decrement the month by one.
        self.decrementCalendarMonth(1)
      else
        @day -= adjust
        self.draw_field
      end
    end

    # This increments the current month by the given value.
    def incrementCalendarMonth(adjust)
      # Are we at the end of the year.
      if @month + adjust > 12
        @month = @month + adjust - 12
        @year += 1
      else
        @month += adjust
      end

      # Get the length of the current month.
      month_length = Calendar.days_in_month(@year, @month)
      if @day > month_length
        @day = month_length
      end

      # Get the start of the current month.
      @week_day = Calendar.month_starting_weekday(@year, @month)

      # Redraw the calendar.
      self.erase
      self.draw
    end

    # This decrements the current month by the given value.
    def decrementCalendarMonth(adjust)
      # Are we at the end of the year.
      if @month <= adjust
        if @year == 1900
          mesg = [
              '<C></U>Error',
              'Can not go past the year 1900',
          ]
          RNDK.beep
          @screen.popup_label(mesg, 2)
          return
        else
          @month = 13 - adjust
          @year -= 1
        end
      else
        @month -= adjust
      end

      # Get the length of the current month.
      month_length = Calendar.days_in_month(@year, @month)
      if @day > month_length
        @day = month_length
      end

      # Get the start o the current month.
      @week_day = Calendar.month_starting_weekday(@year, @month)

      # Redraw the calendar.
      self.erase
      self.draw
    end

    # This increments the current year by the given value.
    def incrementCalendarYear(adjust)
      # Increment the year.
      @year += adjust

      # If we are in Feb make sure we don't trip into voidness.
      if @month == 2
        month_length = Calendar.days_in_month(@year, @month)
        if @day > month_length
          @day = month_length
        end
      end

      # Get the start of the current month.
      @week_day = Calendar.month_starting_weekday(@year, @month)

      # Redraw the calendar.
      self.erase
      self.draw
    end

    # This decrements the current year by the given value.
    def decrementCalendarYear(adjust)
      # Make sure we don't go out o bounds.
      if @year - adjust < 1900
        mesg = [
            '<C></U>Error',
            'Can not go past the year 1900',
        ]
        RNDK.beep
        @screen.popup_label(mesg, 2)
        return
      end

      # Decrement the year.
      @year -= adjust

      # If we are in Feb make sure we don't trip into voidness.
      if @month == 2
        month_length = Calendar.days_in_month(@year, @month)
        if @day > month_length
          @day = month_length
        end
      end

      # Get the start of the current month.
      @week_day = Calendar.month_starting_weekday(@year, @month)

      # Redraw the calendar.
      self.erase
      self.draw
    end

    # Draws the month field.
    def draw_field
      month_name = @month_name[@month]
      month_length = Calendar.days_in_month(@year, @month)
      year_index = Calendar.global_year_index(@year)
      year_len = 0
      save_y = -1
      save_x = -1

      day = (1 - @week_day + (@week_base % 7))
      if day > 0
        day -= 7
      end

      (1..6).each do |row|
        (0...7).each do |col|
          if day >= 1 && day <= month_length
            xpos = col * 3
            ypos = row

            marker = @day_color
            temp = '%02d' % day

            if @day == day
              marker = @highlight
              save_y = ypos + Ncurses.getbegy(@field_win) - Ncurses.getbegy(@input_window)
              save_x = 1
            else
              marker |= self.getMarker(day, @month, year_index)
            end
            Draw.writeCharAttrib(@field_win, xpos, ypos, temp, marker, RNDK::HORIZONTAL, 0, 2)
          end
          day += 1
        end
      end
      Ncurses.wrefresh @field_win

      # Draw the month in.
      if !(@label_win.nil?)
        temp = '%s %d,' % [month_name, @day]
        Draw.writeChar(@label_win, 0, 0, temp, RNDK::HORIZONTAL, 0, temp.size)
        Ncurses.wclrtoeol @label_win

        # Draw the year in.
        temp = '%d' % [@year]
        year_len = temp.size
        Draw.writeChar(@label_win, @field_width - year_len, 0, temp,
            RNDK::HORIZONTAL, 0, year_len)

        Ncurses.wmove(@label_win, 0, 0)
        Ncurses.wrefresh @label_win

      elsif save_y >= 0
        Ncurses.wmove(@input_window, save_y, save_x)
        Ncurses.wrefresh @input_window
      end
    end

  end
end

