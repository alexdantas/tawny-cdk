require 'rndk'

module RNDK
  class Buttonbox < Widget

    def initialize(screen, config={})
      super()
      @widget_type = :buttonbox
      @supported_signals += [:before_pressing, :pressed]

      x           = 0
      y           = 0
      width       = 0
      height      = 0
      title       = "buttonbox"
      buttons     = []
      button_rows = 1
      button_cols = 1
      highlight   = RNDK::Color[:reverse]
      box         = true
      shadow      = false

      config.each do |key, val|
        x           = val if key == :x
        y           = val if key == :y
        width       = val if key == :width
        height      = val if key == :height
        title       = val if key == :title
        button_rows = val if key == :button_rows
        button_cols = val if key == :button_cols
        buttons     = val if key == :buttons
        highlight   = val if key == :highlight
        box         = val if key == :box
        shadow      = val if key == :shadow
      end

      button_count = buttons.size
      parent_width = Ncurses.getmaxx(screen.window)
      parent_height = Ncurses.getmaxy(screen.window)
      col_width = 0
      current_button = 0
      @button = []
      @button_len = []
      @button_pos = []
      @column_widths = []

      if button_count <= 0
        self.destroy
        return nil
      end

      self.set_box(box)

      # Set some default values for the widget.
      @row_adjust = 0
      @col_adjust = 0

      # If the height is a negative value, the height will be
      # BUTTON_ROWS-height, otherwise the height will be the given height.
      box_height = RNDK.set_widget_dimension(parent_height, height, button_rows + 1)

      # If the width is a negative value, the width will be
      # COLS-width, otherwise the width will be the given width.
      box_width = RNDK.set_widget_dimension(parent_width, width, 0)

      box_width = self.set_title(title, box_width)

      # Translate the buttons string to a chtype array
      (0...button_count).each do |x|
        button_len = []
        @button << RNDK.char2Chtype(buttons[x], button_len ,[])
        @button_len << button_len[0]
      end

      # Set the button positions.
      (0...button_cols).each do |x|
        max_col_width = -2**31

        # Look for the widest item in this column.
        (0...button_rows).each do |y|
          if current_button < button_count
            max_col_width = [@button_len[current_button], max_col_width].max
            current_button += 1
          end
        end

        # Keep the maximum column width for this column.
        @column_widths << max_col_width
        col_width += max_col_width
      end
      box_width += 1

      # Make sure we didn't extend beyond the dimensions of the window.
      box_width = [box_width, parent_width].min
      box_height = [box_height, parent_height].min

      # Now we have to readjust the x and y positions
      xtmp = [x]
      ytmp = [y]
      RNDK.alignxy(screen.window, xtmp, ytmp, box_width, box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      # Set up the buttonbox box attributes.
      @screen = screen
      @parent = screen.window
      @win = Ncurses.newwin(box_height, box_width, ypos, xpos)
      @shadow_win = nil
      @button_count = button_count
      @current_button = 0
      @button_rows = button_rows
      @button_cols = [button_count, button_cols].min
      @box_height = box_height
      @box_width = box_width
      @highlight = highlight
      @accepts_focus = true
      @input_window = @win
      @shadow = shadow
      @button_color = RNDK::Color[:normal]

      # Set up the row adjustment.
      if box_height - button_rows - @title_lines > 0
        @row_adjust = (box_height - button_rows - @title_lines) / @button_rows
      end

      # Set the col adjustment
      if box_width - col_width > 0
        @col_adjust = ((box_width - col_width) / @button_cols) - 1
      end

      # If we couldn't create the window, we should return a null value.
      if @win.nil?
        self.destroy
        return nil
      end
      Ncurses.keypad(@win, true)

      # Was there a shadow?
      if shadow
        @shadow_win = Ncurses.newwin(box_height, box_width,
            ypos + 1, xpos + 1)
      end

      # Register this baby.
      screen.register(@widget_type, self)
    end

    # This activates the widget.
    def activate(actions=[])
      # Draw the buttonbox box.
      draw

      if actions.nil? || actions.size == 0
        while true
          input = self.getch

          # Inject the characer into the widget.
          ret = self.inject(input)
          if @exit_type != :EARLY_EXIT
            return ret
          end
        end
      else
        # Inject each character one at a time.
        actions.each do |action|
          ret = self.inject(action)
          if @exit_type != :EARLY_EXIT
            return ret
          end
        end
      end

      # Set the exit type and exit
      self.set_exit_type(0)
      return -1
    end

    # This injects a single character into the widget.
    def inject input
      first_button = 0
      last_button = @button_count - 1
      pp_return = true
      ret = false
      complete = false

      # Set the exit type
      self.set_exit_type(0)

      keep_going = self.run_signal_binding(:before_input, input)

      # Should we continue?
      if keep_going

        # Check for a key binding.
        if self.is_bound? input
          self.run_key_binding input
          #complete = true

        else
          case input
          when Ncurses::KEY_LEFT, Ncurses::KEY_BTAB, Ncurses::KEY_BACKSPACE
            if @current_button - @button_rows < first_button
              @current_button = last_button
            else
              @current_button -= @button_rows
            end
          when Ncurses::KEY_RIGHT, RNDK::KEY_TAB, ' '.ord
            if @current_button + @button_rows > last_button
              @current_button = first_button
            else
              @current_button += @button_rows
            end
          when Ncurses::KEY_UP
            if @current_button -1 < first_button
              @current_button = last_button
            else
              @current_button -= 1
            end
          when Ncurses::KEY_DOWN
            if @current_button + 1 > last_button
              @current_button = first_button
            else
              @current_button += 1
            end
          when RNDK::REFRESH
            @screen.erase
            @screen.refresh

          when RNDK::KEY_ESC
            self.set_exit_type(input)
            complete = true

          when Ncurses::ERR
            self.set_exit_type(input)
            complete = true

          when RNDK::KEY_RETURN, Ncurses::KEY_ENTER
            keep_going = self.run_signal_binding(:before_pressing)

            if keep_going
              self.run_signal_binding(:pressed)
              self.set_exit_type input
              ret = @current_button
              complete = true
            end
          end
        end

        self.run_signal_binding(:after_input) if not complete
      end

      unless complete
        draw_buttons
        self.set_exit_type(0)
      end

      @result_data = ret
      ret
    end

    # This sets multiple attributes of the widget.
    def set(highlight, box)
      self.set_highlight(highlight)
      self.set_box(box)
    end

    # This sets the highlight attribute for the buttonboxes
    def highlight= hilite
      @highlight = hilite
    end

    def highlight
      @highlight
    end

    # This sets th background attribute of the widget.
    def set_bg_color attrib
      Ncurses.wbkgd(@win, attrib)
    end

    # This draws the buttonbox box widget.
    def draw
      Draw.drawShadow(@shadow_win) unless @shadow_win.nil?
      draw_box @win if @box
      draw_title @win
      draw_buttons
    end

    # This erases the buttonbox box from the screen.
    def erase
      if self.valid?
        RNDK.window_erase @win
        RNDK.window_erase @shadow_win
      end
    end

    # This destroys the widget
    def destroy
      self.clean_title

      RNDK.window_delete @shadow_win
      RNDK.window_delete @win

      self.clean_bindings

      @screen.unregister self
    end

    def current_button= button
      @current_button = button if (0...@button_count).member? button

      @current_button = 0 if button < 0
      @current_button = @button_count-1 if button > @button_count-1
    end

    def current_button
      @current_button
    end

    def getButtonCount
      @button_count
    end

    def focus
      draw
    end

    def unfocus
      draw
    end

    def position
      super(@win)
    end

    protected

    # This draws the buttons on the button box widget.
    def draw_buttons
      row = @title_lines + 1
      col = @col_adjust / 2
      current_button = 0
      cur_row = -1
      cur_col = -1

      # Draw the buttons.
      while current_button < @button_count
        (0...@button_cols).each do |x|
          row = @title_lines + @border_size

          (0...@button_rows).each do |y|
            attr = @button_color
            if current_button == @current_button
              attr = @highlight
              cur_row = row
              cur_col = col
            end
            Draw.writeChtypeAttrib(@win,
                                   col,
                                   row,
                                   @button[current_button],
                                   attr,
                                   RNDK::HORIZONTAL,
                                   0,
                                   @button_len[current_button])
            row += (1 + @row_adjust)
            current_button += 1
          end
          col += @column_widths[x] + @col_adjust + @border_size
        end
      end

      if cur_row >= 0 && cur_col >= 0
        Ncurses.wmove(@win, cur_row, cur_col)
      end
      Ncurses.wrefresh @win
    end

  end
end

