require 'rndk'

module RNDK

  # Allows user to select from a items of alphabetically sorted
  # words.
  #
  # Use the arrow keys to navigate on the items or type in the
  # beginning of the word and it'll automagically adjust
  # itself in the correct place.
  #
  # ## Keybindings
  #
  # Since Alphaitems is built from both the Scroll and Entry Widgets,
  # the key bindings are the same for the respective fields.
  #
  # Extra key bindings are itemsed below:
  #
  # Up Arrow::   Scrolls the scrolling items up one line.
  # Down Arrow:: Scrolls the scrolling items down one line.
  # Page Up::    Scrolls the scrolling items up one page.
  # CTRL-B::     Scrolls the scrolling items up one page.
  # Page Down::  Scrolls the scrolling items down one page.
  # CTRL-F::     Scrolls the scrolling items down one page.
  # Tab::        Tries to complete the word in the entry field.
  #              If the word segment is not unique then the widget
  #              will beep  and  present  a items of close matches.
  # Return::     Returns the word in the entry field.
  #              It  also  sets  the widget data exitType to `:NORMAL`.
  # Escape::     Exits the widget and returns `nil`.
  #              It  also sets the widget data exitType to `:ESCAPE_HIT`.
  #
  # ## Developer notes
  #
  # This widget, like the file selector widget, is a compound widget
  # of both the entry field widget and the scrolling items widget - sorted.
  #
  # @todo Kinda buggy, fix first words, mate
  #
  class Alphalist < Widget
    attr_reader :scroll_field, :entry_field, :items

    # Creates an Alphalist Widget.
    #
    # ## Settings
    #
    # * `x` is the x position - can be an integer or `RNDK::LEFT`,
    #   `RNDK::RIGHT`, `RNDK::CENTER`.
    # * `y` is the y position - can be an integer or `RNDK::TOP`,
    #   `RNDK::BOTTOM`, `RNDK::CENTER`.
    # * `width`/`height` are integers - if either are 0, Widget
    #   will be created with full width/height of the screen.
    #   If it's a negative value, will create with full width/height
    #   minus the value.
    # * `title` can be more than one line - just split them
    #   with `\n`s.
    # * `label` is the String that will appear on the label
    #   of the Entry field.
    # * `items` is an Array of Strings with the content to
    #   display.
    # * `filler_char` is the character to display on the
    #   empty spaces in the Entry field.
    # * `highlight` is the attribute/color of the current
    #   item.
    # * `box` if the Widget is drawn with a box outside it.
    # * `shadow` turns on/off the shadow around the Widget.
    #
    def initialize(screen, config={})
      super()
      @widget_type  = :alphaitems
      @supported_signals += [:before_input, :after_input]

      # This is UGLY AS HELL
      # But I don't have time to clean this up right now
      # (lots of widgets, you know)  :(
      x           = 0
      y           = 0
      width       = 0
      height      = 0
      title       = "alphaitems"
      label       = "label"
      items        = []
      filler_char = '.'
      highlight   = RNDK::Color[:reverse]
      box         = true
      shadow      = false

      config.each do |key, val|
        x           = val if key == :x
        y           = val if key == :y
        width       = val if key == :width
        height      = val if key == :height
        title       = val if key == :title
        label       = val if key == :label
        items        = val if key == :items
        filler_char = val if key == :filler_char
        highlight   = val if key == :highlight
        box         = val if key == :box
        shadow      = val if key == :shadow
      end

      parent_width  = Ncurses.getmaxx screen.window
      parent_height = Ncurses.getmaxy screen.window

      box_width  = width
      box_height = height

      label_len = 0

      if not self.create_items items
        self.destroy
        return nil
      end

      self.set_box box

      # If the height is a negative value, the height will be ROWS-height,
      # otherwise the height will be the given height.
      box_height = RNDK.set_widget_dimension(parent_height, height, 0)

      # If the width is a negative value, the width will be COLS-width,
      # otherwise the width will be the given width.
      box_width = RNDK.set_widget_dimension(parent_width, width, 0)

      # Translate the label string to a chtype array
      if label.size > 0
        lentmp = []
        chtype_label = RNDK.char2Chtype(label, lentmp, [])
        label_len = lentmp[0]
      end

      # Rejustify the x and y positions if we need to.
      xtmp = [x]
      ytmp = [y]
      RNDK.alignxy(screen.window, xtmp, ytmp, box_width, box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      # Make the file selector window.
      @win = Ncurses.newwin(box_height, box_width, ypos, xpos)

      if @win.nil?
        self.destroy
        return nil
      end
      Ncurses.keypad(@win, true)

      @screen = screen
      @parent = screen.window
      @highlight   = highlight
      @filler_char = filler_char

      @box_width  = box_width
      @box_height = box_height

      @shadow = shadow
      @shadow_win = nil

      # Do we want a shadow?
      if shadow
        @shadow_win = Ncurses.newwin(box_height, box_width, ypos+1, xpos+1)
      end

      # Create the entry field.
      temp_width =  if Alphalist.isFullWidth(width)
                    then RNDK::FULL
                    else box_width - 2 - label_len
                    end

      @entry_field = RNDK::Entry.new(screen, {
                                       :x => Ncurses.getbegx(@win),
                                       :y => Ncurses.getbegy(@win),
                                       :title => title,
                                       :label => label,
                                       :filler => filler_char,
                                       :field_width => temp_width,
                                       :box => box
                                     })
      if @entry_field.nil?
        self.destroy
        return nil
      end
      @entry_field.setLLchar Ncurses::ACS_LTEE
      @entry_field.setLRchar Ncurses::ACS_RTEE

      # Set the key bindings for the entry field.
      @entry_field.bind_key(Ncurses::KEY_UP)    { self.autocomplete }
      @entry_field.bind_key(RNDK::KEY_TAB)      { self.autocomplete }
      @entry_field.bind_key(Ncurses::KEY_DOWN)  { self.adjust_items }
      @entry_field.bind_key(Ncurses::KEY_NPAGE) { self.adjust_items }
      @entry_field.bind_key(Ncurses::KEY_PPAGE) { self.adjust_items }

      @entry_field.bind_signal(:before_input) { |char| self.pre_process_entry_field(char) }

      # Create the scrolling items.  It overlaps the entry field by one line if
      # we are using box-borders.
      temp_height = Ncurses.getmaxy(@entry_field.win) - @border_size
      temp_width = if Alphalist.isFullWidth(width)
                   then RNDK::FULL
                   else box_width - 1
                   end

      @scroll_field = RNDK::Scroll.new(screen, {
                                         :x => Ncurses.getbegx(@win),
                                         :y => Ncurses.getbegy(@entry_field.win) + temp_height,
                                         :width => temp_width,
                                         :height => box_height - temp_height,
                                         :title => '',
                                         :items => items,
                                         :box => box
                                       })

      @scroll_field.setULchar Ncurses::ACS_LTEE
      @scroll_field.setURchar Ncurses::ACS_RTEE

      screen.register(:alphaitems, self)
    end

    # @see Widget#erase
    def erase
      if self.valid?
        @scroll_field.erase
        @entry_field.erase

        RNDK.window_erase(@shadow_win)
        RNDK.window_erase(@win)
      end
    end

    # @see Widget#move
    def move(x, y, relative, refresh_flag)
      windows = [@win, @shadow_win]
      subwidgets = [@entry_field, @scroll_field]
      self.move_specific(x, y, relative, refresh_flag, windows, subwidgets)
    end

    # The alphaitems's focus resides in the entry widget. But the scroll widget
    # will not draw items highlighted unless it has focus. Temporarily adjust
    # the focus of the scroll widget when drawing on it to get the right
    # highlighting.
    def saveFocus
      @save = @scroll_field.has_focus
      @scroll_field.has_focus = @entry_field.has_focus
    end

    def restoreFocus
      @scroll_field.has_focus = @save
    end

    def draw_scroller
      self.saveFocus
      @scroll_field.draw
      self.restoreFocus
    end

    def injectMyScroller(key)
      self.saveFocus
      @scroll_field.inject(key)
      self.restoreFocus
    end

    # Draws the Widget on the Screen.
    #
    # If `box` is true, it is drawn with a box.
    def draw
      Draw.drawShadow @shadow_win unless @shadow_win.nil?

      # Draw in the entry field.
      @entry_field.draw @entry_field.box

      # Draw in the scroll field.
      self.draw_scroller
    end

    # Activates the Alphalist Widget, letting the user interact with it.
    #
    # `actions` is an Array of characters. If it's non-null,
    # will #inject each char on it into the Widget.
    #
    # See Alphalist for keybindings.
    #
    # @return The text currently inside the entry field (and
    #         `exit_type` will be `:NORMAL`) or `nil` (and
    #         `exit_type` will be `:ESCAPE_HIT`).
    def activate(actions=[])
      ret = 0

      # Draw the widget.
      self.draw

      # Activate the widget.
      ret = @entry_field.activate actions

      # Copy the exit type from the entry field.
      @exit_type = @entry_field.exit_type

      # Determine the exit status.
      if @exit_type != :EARLY_EXIT
        return ret
      end
      return 0
    end

    # Makes the Alphalist react to `char` just as if the user
    # had pressed it.
    #
    # Nice to simulate batch actions on a Widget.
    #
    # Besides normal keybindings (arrow keys and such), see
    # Widget#set_exit_type to see how the Widget exits.
    #
    def inject input
      ret = false

      self.draw

      # Inject a character into the widget.
      ret = @entry_field.inject input

      # Copy the eixt type from the entry field.
      @exit_type = @entry_field.exit_type

      # Determine the exit status.
      ret = false if @exit_type == :EARLY_EXIT

      @result_data = ret
      ret
    end

    # Sets multiple attributes of the Widget.
    #
    # See Alphalist#initialize.
    def set(items, filler_char, highlight, box)
      self.set_contents   items
      self.set_filler_char filler_char
      self.set_highlight highlight
      self.set_box box
    end

    # This function sets the textrmation inside the alphaitems.
    def set_contents items
      return if not self.create_items items

      # Set the textrmation in the scrolling items.
      @scroll_field.set(@items, @items_size, false,
          @scroll_field.highlight, @scroll_field.box)

      # Clean out the entry field.
      self.set_current_item(0)
      @entry_field.clean

      # Redraw the widget.
      self.erase
      self.draw
    end

    # This returns the contents of the widget.
    def getContents size
      size << @items_size
      return @items
    end

    # Get/set the current position in the scroll widget.
    def get_current_item
      return @scroll_field.get_current_item
    end

    def set_current_item item
      if @items_size != 0
        @scroll_field.set_current_item item
        @entry_field.setValue @items[@scroll_field.get_current_item]
      end
    end

    # This sets the filler character of the entry field of the alphaitems.
    def set_filler_char char
      @filler_char = char
      @entry_field.set_filler_char char
    end

    def get_filler_char
      return @filler_char
    end

    # This sets the highlgith bar attributes
    def set_highlight(highlight)
      @highlight = highlight
    end

    def getHighlight
      @highlight
    end

    # These functions set the drawing characters of the widget.
    def setMyULchar(character)
      @entry_field.setULchar(character)
    end

    def setMyURchar(character)
      @entry_field.setURchar(character)
    end

    def setMyLLchar(character)
      @scroll_field.setLLchar(character)
    end

    def setMyLRchar(character)
      @scroll_field.setLRchar(character)
    end

    def setMyVTchar(character)
      @entry_field.setVTchar(character)
      @scroll_field.setVTchar(character)
    end

    def setMyHZchar(character)
      @entry_field.setHZchar(character)
      @scroll_field.setHZchar(character)
    end

    def setMyBXattr(character)
      @entry_field.setBXattr(character)
      @scroll_field.setBXattr(character)
    end

    # This sets the background attribute of the widget.
    def set_bg_color(attrib)
      @entry_field.set_bg_color(attrib)
      @scroll_field.set_bg_color(attrib)
    end

    def destroyText
      @items = ''
      @items_size = 0
    end

    # This destroys the alpha items
    def destroy
      self.destroyText

      # Clean the key bindings.
      self.clean_bindings

      @entry_field.destroy
      @scroll_field.destroy

      # Free up the window pointers.
      RNDK.window_delete(@shadow_win)
      RNDK.window_delete(@win)

      # Unregister the widget.
      @screen.unregister self
    end

    # @see Widget#bind_signal
    def bind_signal(signal, &action)
      @entry_field.bind_signal(signal, action)
    end

    def create_items items
      if items.size >= 0
        newitems = []

        # Copy in the new textrmation.
        status = true
        (0...items.size).each do |x|
          newitems << items[x]
          if newitems[x] == 0
            status = false
            break
          end
        end
        if status
          self.destroyText
          @items_size = items.size
          @items = newitems
          @items.sort!
        end
      else
        self.destroyText
        status = true
      end
      status
    end

    def focus
      self.entry_field.focus
    end

    def unfocus
      self.entry_field.unfocus
    end

    def self.isFullWidth(width)
      width == RNDK::FULL || (Ncurses.COLS != 0 && width >= Ncurses.COLS)
    end

    def position
      super(@win)
    end


    protected

    def autocomplete
      scrollp = self.scroll_field
      entry   = self.entry_field

      if scrollp.items_size > 0
        # Adjust the scrolling items.
        self.injectMyScroller Ncurses::KEY_UP

        # Set the value in the entry field.
        current = RNDK.chtype2Char scrollp.item[scrollp.current_item]
        entry.setValue current
        entry.draw entry.box
        return true
      end

      RNDK.beep
      false
    end

    def adjust_items
      entry = self.entry_field
      scrollp = nil
      selected = -1
      ret = 0
      alt_words = []

      if entry.text.size == 0
        RNDK.beep
        return true
      end

      # Look for a unique word match.
      index = RNDK.search_list(self.items, self.items.size, entry.text)

      # if the index is less than zero, return we didn't find a match
      if index < 0
        RNDK.beep
        return true
      end

      # Did we find the last word in the items?
      if index == self.items.size - 1
        entry.setValue self.items[index]
        entry.draw entry.box
        return true
      end

      # Ok, we found a match, is the next item similar?
      len = [entry.text.size, self.items[index + 1].size].min
      ret = self.items[index + 1][0...len] <=> entry.text
      if ret == 0
        current_index = index
        match = 0
        selected = -1

        # Start looking for alternate words
        # FIXME(original): bsearch would be more suitable.
        while (current_index < self.items.size) and
            ((self.items[current_index][0...len] <=> entry.text) == 0)
          alt_words << self.items[current_index]
          current_index += 1
        end

        # Determine the height of the scrolling items.
        height = if alt_words.size < 8 then alt_words.size + 3 else 11 end

        # Create a scrolling items of close matches.
        scrollp = RNDK::Scroll.new(entry.screen, {
                                     :x => RNDK::CENTER,
                                     :y => RNDK::CENTER,
                                     :width => -30,
                                     :height => height,
                                     :title => "<C></B/5>Possible Matches.",
                                     :items => alt_words,
                                     :numbers => true
                                   })

        # Allow them to select a close match.
        match = scrollp.activate
        selected = scrollp.current_item

        # Check how they exited the items.
        if scrollp.exit_type == :ESCAPE_HIT
          # Destroy the scrolling items.
          scrollp.destroy

          RNDK.beep

          # Redraw the self and return.
          self.draw(self.box)
          return true
        end

        # Destroy the scrolling items.
        scrollp.destroy

        # Set the entry field to the selected value.
        entry.set(alt_words[match], entry.min, entry.max, entry.box)

        # Move the highlight bar down to the selected value.
        (0...selected).each do |x|
          self.injectMyScroller(Ncurses::KEY_DOWN)
        end

        # Redraw the self.
        self.draw self.box

      else
        # Set the entry field with the found item.
        entry.set(self.items[index], entry.min, entry.max, entry.box)
        entry.draw entry.box
      end
      true
    end

    def pre_process_entry_field(input)
      scrollp = self.scroll_field
      entry = self.entry_field
      text_len = entry.text.size
      result = 1
      empty = false

      if self.is_bound? input
        result = 1  # Don't try to use this key in editing

      elsif (RNDK.is_char?(input) &&
             input.chr.match(/^[[:alnum:][:punct:]]$/)) ||
        [Ncurses::KEY_BACKSPACE, Ncurses::KEY_DC].include?(input)

        index = 0
        curr_pos = entry.screen_col + entry.left_char
        pattern = entry.text.clone

        if [Ncurses::KEY_BACKSPACE, Ncurses::KEY_DC].include? input

          curr_pos -= 1 if input == Ncurses::KEY_BACKSPACE

          pattern.slice!(curr_pos) if curr_pos >= 0

        else
          front   = (pattern[0...curr_pos] or '')
          back    = (pattern[curr_pos..-1] or '')
          pattern = front + input.chr + back
        end

        if pattern.size == 0
          empty = true

        elsif (index = RNDK.search_list(self.items,
                                         self.items.size,
                                         pattern)) >= 0

          # XXX: original uses n scroll downs/ups for <10 positions change
          scrollp.set_position(index)
          self.draw_scroller

        else
          RNDK.beep
          result = 0
        end
      end

      if empty
        scrollp.set_position(0)
        self.draw_scroller
      end

      result
    end

  end
end
