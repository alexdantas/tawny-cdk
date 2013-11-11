require 'rndk'

module RNDK
  class MATRIX < RNDK::Widget
    attr_accessor :info
    attr_reader :colvalues, :row, :col, :colwidths, :filler
    attr_reader :crow, :ccol
    MAX_MATRIX_ROWS = 1000
    MAX_MATRIX_COLS = 1000

    @@g_paste_buffer = ''

    def initialize(rndkscreen, xplace, yplace, rows, cols, vrows, vcols,
        title, rowtitles, coltitles, colwidths, colvalues, rspace, cspace,
        filler, dominant, box, box_cell, shadow)
      super()
      parent_width = Ncurses.getmaxx(rndkscreen.window)
      parent_height = Ncurses.getmaxy(rndkscreen.window)
      box_height = 0
      box_width = 0
      max_row_title_width = 0
      row_space = [0, rspace].max
      col_space = [0, cspace].max
      begx = 0
      begy = 0
      cell_width = 0
      have_rowtitles = false
      have_coltitles = false
      bindings = {
          RNDK::FORCHAR  => Ncurses::KEY_NPAGE,
          RNDK::BACKCHAR => Ncurses::KEY_PPAGE,
      }

      self.set_box(box)
      borderw = if @box then 1 else 0 end

      # Make sure that the number of rows/cols/vrows/vcols is not zero.
      if rows <= 0 || cols <= 0 || vrows <= 0 || vcols <= 0
        self.destroy
        return nil
      end

      @cell = Array.new(rows + 1) { |i| Array.new(cols + 1)}
      @info = Array.new(rows + 1) { |i| Array.new(cols + 1) { |i| '' }}

      # Make sure the number of virtual cells is not larger than the
      # physical size.
      vrows = [vrows, rows].min
      vcols = [vcols, cols].min

      @rows = rows
      @cols = cols
      @colwidths = [0] * (cols + 1)
      @colvalues = [0] * (cols + 1)
      @coltitle = Array.new(cols + 1) {|i| []}
      @coltitle_len = [0] * (cols + 1)
      @coltitle_pos = [0] * (cols + 1)
      @rowtitle = Array.new(rows + 1) {|i| []}
      @rowtitle_len = [0] * (rows + 1)
      @rowtitle_pos = [0] * (rows + 1)

      # Count the number of lines in the title
      temp = title.split("\n")
      @title_lines = temp.size

      # Determine the height of the box.
      if vrows == 1
        box_height = 6 + @title_lines
      else
        if row_space == 0
          box_height = 6 + @title_lines + (vrows - 1) * 2
        else
          box_height = 3 + @title_lines + vrows * 3 +
              (vrows - 1) * (row_space - 1)
        end
      end

      # Determine the maximum row title width.
      (1..rows).each do |x|
        if !(rowtitles.nil?) && x < rowtitles.size && rowtitles[x].size > 0
          have_rowtitles = true
        end
        rowtitle_len = []
        rowtitle_pos = []
        @rowtitle[x] = RNDK.char2Chtype((rowtitles[x] || ''),
            rowtitle_len, rowtitle_pos)
        @rowtitle_len[x] = rowtitle_len[0]
        @rowtitle_pos[x] = rowtitle_pos[0]
        max_row_title_width = [max_row_title_width, @rowtitle_len[x]].max
      end

      if have_rowtitles
        @maxrt = max_row_title_width + 2

        # We need to rejustify the row title cell info.
        (1..rows).each do |x|
          @rowtitle_pos[x] = RNDK.justifyString(@maxrt,
              @rowtitle_len[x], @rowtitle_pos[x])
        end
      else
        @maxrt = 0
      end

      # Determine the width of the matrix.
      max_width = 2 + @maxrt
      (1..vcols).each do |x|
        max_width += colwidths[x] + 2 + col_space
      end
      max_width -= (col_space - 1)
      box_width = [max_width, box_width].max
      box_width = self.setTitle(title, box_width)

      # Make sure the dimensions of the window didn't extend
      # beyond the dimensions of the parent window
      box_width = [box_width, parent_width].min
      box_height = [box_height, parent_height].min

      # Rejustify the x and y positions if we need to.
      xtmp = [xplace]
      ytmp = [yplace]
      RNDK.alignxy(rndkscreen.window, xtmp, ytmp, box_width, box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      # Make the pop-up window.
      @win = Ncurses.newwin(box_height, box_width, ypos, xpos)

      if @win.nil?
        self.destroy
        return nil
      end

      # Make the subwindows in the pop-up.
      begx = xpos
      begy = ypos + borderw + @title_lines

      # Make the 'empty' 0x0 cell.
      @cell[0][0] = Ncurses.subwin(@win, 3, @maxrt, begy, begx)

      begx += @maxrt + 1

      # Copy the titles into the structrue.
      (1..cols).each do |x|
        if !(coltitles.nil?) && x < coltitles.size && coltitles[x].size > 0
          have_coltitles = true
        end
        coltitle_len = []
        coltitle_pos = []
        @coltitle[x] = RNDK.char2Chtype(coltitles[x] || '',
            coltitle_len, coltitle_pos)
        @coltitle_len[x] = coltitle_len[0]
        @coltitle_pos[x] = @border_size + RNDK.justifyString(
            colwidths[x], @coltitle_len[x], coltitle_pos[0])
        @colwidths[x] = colwidths[x]
      end

      if have_coltitles
        # Make the column titles.
        (1..vcols).each do |x|
          cell_width = colwidths[x] + 3
          @cell[0][x] = Ncurses.subwin(@win, borderw, cell_width, begy, begx)
          if @cell[0][x].nil?
            self.destroy
            return nil
          end
          begx += cell_width + col_space - 1
        end
        begy += 1
      end

      # Make the main cell body
      (1..vrows).each do |x|
        if have_rowtitles
          # Make the row titles
          @cell[x][0] = Ncurses.subwin(@win, 3, @maxrt, begy, xpos + borderw)

          if @cell[x][0].nil?
            self.destroy
            return nil
          end
        end

        # Set the start of the x position.
        begx = xpos + @maxrt + borderw

        # Make the cells
        (1..vcols).each do |y|
          cell_width = colwidths[y] + 3
          @cell[x][y] = Ncurses.subwin(@win, 3, cell_width, begy, begx)

          if @cell[x][y].nil?
            self.destroy
            return nil
          end
          begx += cell_width + col_space - 1
          Ncurses.keypad(@cell[x][y], true)
        end
        begy += row_space + 2
      end
      Ncurses.keypad(@win, true)

      # Keep the rest of the info.
      @screen = rndkscreen
      @accepts_focus = true
      @input_window = @win
      @parent = rndkscreen.window
      @vrows = vrows
      @vcols = vcols
      @box_width = box_width
      @box_height = box_height
      @row_space = row_space
      @col_space = col_space
      @filler = filler.ord
      @dominant = dominant
      @row = 1
      @col = 1
      @crow = 1
      @ccol = 1
      @trow = 1
      @lcol = 1
      @oldcrow = 1
      @oldccol = 1
      @oldvrow = 1
      @oldvcol = 1
      @box_cell = box_cell
      @shadow = shadow
      @highlight = Ncurses::A_REVERSE
      @shadow_win = nil
      @callbackfn = lambda do |matrix, input|
        disptype = matrix.colvanlues[matrix.col]
        plainchar = Display.filter_by_display_type(disptype, input)
        charcount = matrix.info[matrix.row][matrix.col].size

        if plainchar == Ncurses::ERR
          RNDK.beep
        elsif charcount == matrix.colwidths[matrix.col]
          RNDK.beep
        else
          # Update the screen.
          Ncurses.wmove(matrix.CurMatrixCell,
                        1,
                        matrix.info[matrix.row][matrix.col].size + 1)
          Ncurses.waddch(matrix.CurMatrixCell,
                         if Display.is_hidden_display_type(disptype)
                         then matrix.filler
                         else plainchar
                         end)
          Ncurses.wrefresh matrix.CurMatrixCell

          # Update the info string
          matrix.info[matrix.row][matrix.col] =
              matrix.info[matrix.row][matrix.col][0...charcount] +
              plainchar.chr
        end
      end

      # Make room for the cell information.
      (1..rows).each do |x|
        (1..cols).each do |y|
          @colvalues[y] = colvalues[y]
          @colwidths[y] = colwidths[y]
        end
      end

      @colvalues = colvalues.clone
      @colwidths = colwidths.clone

      # Do we want a shadow?
      if shadow
        @shadow_win = Ncurses.newwin(box_height, box_width,
            ypos + 1, xpos + 1)
      end

      # Set up the key bindings.
      bindings.each do |from, to|
        self.bind(:MATRIX, from, :getc, to)
      end

      # Register this baby.
      rndkscreen.register(:MATRIX, self)
    end

    # This activates the matrix.
    def activate(actions)
      self.draw(@box)

      if actions.nil? || actions.size == 0
        while true
          @input_window = self.CurMatrixCell
          Ncurses.keypad(@input_window, true)
          input = self.getch([])

          # Inject the character into the widget.
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

      # Set the exit type and exit.
      self.set_exit_type(0)
      return -1
    end

    # This injects a single character into the matrix widget.
    def inject(input)
      refresh_cells = false
      moved_cell = false
      charcount = @info[@row][@col].size
      pp_return = 1
      ret = -1
      complete = false

      # Set the exit type.
      self.set_exit_type(0)

      # Move the cursor to the correct position within the cell.
      if @colwidths[@ccol] == 1
        Ncurses.wmove(self.CurMatrixCell, 1, 1)
      else
        Ncurses.wmove(self.CurMatrixCell, 1, @info[@row][@col].size + 1)
      end

      # Put the focus on the current cell.
      self.focusCurrent

      # Check if there is a pre-process function to be called.
      unless @pre_process_func.nil?
        # Call the pre-process function.
        pp_return = @pre_process_func.call(:MATRIX, self,
            @pre_process_data, input)
      end

      # Should we continue?
      if pp_return != 0
        # Check the key bindings.
        if self.checkBind(:MATRIX, input)
          complete = true
        else
          case input
          when RNDK::TRANSPOSE
          when Ncurses::KEY_HOME
          when Ncurses::KEY_END
          when Ncurses::KEY_BACKSPACE, Ncurses::KEY_DC
            if @colvalues[@col] == :VIEWONLY || charcount <= 0
              RNDK.beep
            else
              charcount -= 1
              Ncurses.mvwdelch(self.CurMatrixCell, 1, charcount + 1)
              Ncurses.mvwinsch(self.CurMatrixCell, 1, charcount + 1, @filler)

              Ncurses.wrefresh self.CurMatrixCell
              @info[@row][@col] = @info[@row][@col][0...charcount]
            end
          when Ncurses::KEY_RIGHT, RNDK::KEY_TAB
            if @ccol != @vcols
              # We are moving to the right...
              @col += 1
              @ccol += 1
              moved_cell = true
            else
              # We have to shift the columns to the right.
              if @col != @cols
                @lcol += 1
                @col += 1

                # Redraw the column titles.
                if @rows > @vrows
                  self.redrawTitles(false, true)
                end
                refresh_cells = true
                moved_cell = true
              else
                # We are at the far right column, we need to shift
                # down one row, if we can.
                if @row == @rows
                  RNDK.beep
                else
                  # Set up the columns info.
                  @col = 1
                  @lcol = 1
                  @ccol = 1

                  # Shift the rows...
                  if @crow != @vrows
                    @row += 1
                    @crow += 1
                  else
                    @row += 1
                    @trow += 1
                  end
                  self.redrawTitles(true, true)
                  refresh_cells = true
                  moved_cell = true
                end
              end
            end
          when Ncurses::KEY_LEFT, Ncurses::KEY_BTAB
            if @ccol != 1
              # We are moving to the left...
              @col -= 1
              @ccol -= 1
              moved_cell = true
            else
              # Are we at the far left?
              if @lcol != 1
                @lcol -= 1
                @col -= 1

                # Redraw the column titles.
                if @cols > @vcols
                  self.redrawTitles(false, true)
                end
                refresh_cells = true
                moved_cell = true
              else
                # Shift up one line if we can...
                if @row == 1
                  RNDK.beep
                else
                  # Set up the columns info.
                  @col = @cols
                  @lcol = @cols - @vcols + 1
                  @ccol = @vcols

                  # Shift the rows...
                  if @crow != 1
                    @row -= 1
                    @crow -= 1
                  else
                    @row -= 1
                    @trow -= 1
                  end
                  self.redrawTitles(true, true)
                  refresh_cells = true
                  moved_cell = true
                end
              end
            end
          when Ncurses::KEY_UP
            if @crow != 1
              @row -= 1
              @crow -= 1
              moved_cell = true
            else
              if @trow != 1
                @trow -= 1
                @row -= 1

                # Redraw the row titles.
                if @rows > @vrows
                  self.redrawTitles(true, false)
                end
                refresh_cells = true
                moved_cell = true
              else
                RNDK.beep
              end
            end
          when Ncurses::KEY_DOWN
            if @crow != @vrows
              @row += 1
              @crow += 1
              moved_cell = true
            else
              if @trow + @vrows - 1 != @rows
                @trow += 1
                @row += 1

                # Redraw the titles.
                if @rows > @vrows
                  self.redrawTitles(true, false)
                end
                refresh_cells = true
                moved_cell = true
              else
                RNDK.beep
              end
            end
          when Ncurses::KEY_NPAGE
            if @rows > @vrows
              if @trow + (@vrows - 1) * 2 <= @rows
                @trow += @vrows - 1
                @row += @vrows - 1
                self.redrawTitles(true, false)
                refresh_cells = true
                moved_cell = true
              else
                RNDK.beep
              end
            else
              RNDK.beep
            end
          when Ncurses::KEY_PPAGE
            if @rows > @vrows
              if @trow - (@vrows - 1) * 2 >= 1
                @trow -= @vrows - 1
                @row -= @vrows - 1
                self.redrawTitles(true, false)
                refresh_cells = true
                moved_cell = true
              else
                RNDK.beep
              end
            else
              RNDK.beep
            end
          when RNDK.CTRL('G')
            self.jumpToCell(-1, -1)
            self.draw(@box)
          when RNDK::PASTE
            if @@g_paste_buffer.size == 0 ||
                @@g_paste_buffer.size > @colwidths[@ccol]
              RNDK.beep
            else
              self.CurMatrixInfo = @@g_paste_buffer.clone
              self.drawCurCell
            end
          when RNDK::COPY
            @@g_paste_buffer = self.CurMatrixInfo.clone
          when RNDK::CUT
            @@g_paste_buffer = self.CurMatrixInfo.clone
            self.cleanCell(@trow + @crow - 1, @lcol + @ccol - 1)
            self.drawCurCell
          when RNDK::ERASE
            self.cleanCell(@trow + @crow - 1, @lcol + @ccol - 1)
            self.drawCurCell
          when Ncurses::KEY_ENTER, RNDK::KEY_RETURN
            if !@box_cell
              Draw.attrbox(@cell[@oldcrow][@oldccol], ' '.ord, ' '.ord,
                  ' '.ord, ' '.ord, ' '.ord, ' '.ord, Ncurses::A_NORMAL)
            else
              self.drawOldCell
            end
            Ncurses.wrefresh self.CurMatrixCell
            self.set_exit_type(input)
            ret = 1
            complete = true
          when Ncurses::ERR
            self.set_exit_type(input)
            complete = true
          when RNDK::KEY_ESC
            if !@box_cell
              Draw.attrbox(@cell[@oldcrow][@oldccol], ' '.ord, ' '.ord,
                  ' '.ord, ' '.ord, ' '.ord, ' '.ord, Ncurses::A_NORMAL)
            else
              self.drawOldCell
            end
            Ncurses.wrefresh self.CurMatrixCell
            self.set_exit_type(input)
            complete = true
          when RNDK::REFRESH
            @screen.erase
            @screen.refresh
          else
            @callbackfn.call(self, input)
          end
        end

        if !complete
          # Did we change cells?
          if moved_cell
            # un-highlight the old box
            if !@box_cell
              Draw.attrbox(@cell[@oldcrow][@oldccol], ' '.ord, ' '.ord,
                  ' '.ord, ' '.ord, ' '.ord, ' '.ord, Ncurses::A_NORMAL)
            else
              self.drawOldCell
            end
            Ncurses.wrefresh(@cell[@oldcrow][@oldccol])

            self.focusCurrent
          end

          # Redraw each cell
          if refresh_cells
            self.drawEachCell
            self.focusCurrent
          end

          # Move to the correct position in the cell.
          if refresh_cells || moved_cell
            if @colwidths[@ccol] == 1
              Ncurses.wmove(self.CurMatrixCell, 1, 1)
            else
              Ncurses.wmove(self.CurMatrixCell, 1, self.CurMatrixInfo.size + 1)
            end
            Ncurses.wrefresh self.CurMatrixCell
          end

          # Should we call a post-process?
          unless @post_process_func.nil?
            @post_process_func.call(:MATRIX, self, @post_process_data, input)
          end
        end
      end

      if !complete
        # Set the variables we need.
        @oldcrow = @crow
        @oldccol = @ccol
        @oldvrow = @row
        @oldvcol = @col

        # Set the exit type and exit.
        self.set_exit_type(0)
      end

      @result_data = ret
      return ret
    end

    # Highlight the new field.
    def highlightCell
      disptype = @colvalues[@col]
      highlight = @highlight
      infolen = @info[@row][@col].size

      # Given the dominance of the color/attributes, we need to set the
      # current cell attribute.
      if @dominant == RNDK::ROW
        highlight = (@rowtitle[@crow][0] || 0) & Ncurses::A_ATTRIBUTES
      elsif @dominant == RNDK::COL
        highlight = (@coltitle[@ccol][0] || 0) & Ncurses::A_ATTRIBUTES
      end

      # If the column is only one char.
      (1..@colwidths[@ccol]).each do |x|
        ch = if x <= infolen && !Display.is_hidden_display_type(disptype)
             then RNDK.CharOf(@info[@row][@col][x - 1])
             else @filler
             end
        Ncurses.mvwaddch(self.CurMatrixCell, 1, x, ch.ord | highlight)
      end
      Ncurses.wmove(self.CurMatrixCell, 1, infolen + 1)
      Ncurses.wrefresh self.CurMatrixCell
    end

    # This moves the matrix field to the given location.
    def move(xplace, yplace, relative, refresh_flag)
      windows = [@win]

      (0..@vrows).each do |x|
        (0..@vcols).each do |y|
          windows << @cell[x][y]
        end
      end

      windows << @shadow_win
      self.move_specific(xplace, yplace, relative, refresh_flag, windows, [])
    end

    # This draws a cell within a matrix.
    def drawCell(row, col, vrow, vcol, attr, box)
      disptype = @colvalues[@col]
      highlight = @filler & Ncurses::A_ATTRIBUTES
      rows = @vrows
      cols = @vcols
      infolen = @info[vrow][vcol].size

      # Given the dominance of the colors/attributes, we need to set the
      # current cell attribute.
      if @dominant == RNDK::ROW
        highlight = (@rowtitle[row][0] || 0) & Ncurses::A_ATTRIBUTES
      elsif @dominant == RNDK::COL
        highlight = (@coltitle[col][0] || 0) & Ncurses::A_ATTRIBUTES
      end

      # Draw in the cell info.
      (1..@colwidths[col]).each do |x|
        ch = if x <= infolen && !Display.is_hidden_display_type(disptype)
             then RNDK.CharOf(@info[vrow][vcol][x-1]).ord | highlight
             else @filler
             end
        Ncurses.mvwaddch(@cell[row][col], 1, x, ch.ord | highlight)
      end

      Ncurses.wmove(@cell[row][col], 1, infolen + 1)
      Ncurses.wrefresh(@cell[row][col])

      # Only draw the box iff the user asked for a box.
      if !box
        return
      end

      # If the value of the column spacing is greater than 0 then these
      # are independent boxes
      if @col_space != 0 && @row_space != 0
        Draw.attrbox(@cell[row][col], Ncurses::ACS_ULCORNER,
            Ncurses::ACS_URCORNER, Ncurses::ACS_LLCORNER,
            Ncurses::ACS_LRCORNER, Ncurses::ACS_HLINE,
            Ncurses::ACS_VLINE, attr)
        return
      end
      if @col_space != 0 && @row_space == 0
        if row == 1
          Draw.attrbox(@cell[row][col], Ncurses::ACS_ULCORNER,
              Ncurses::ACS_URCORNER, Ncurses::ACS_LTEE,
              Ncurses::ACS_RTEE, Ncurses::ACS_HLINE,
              Ncurses::ACS_VLINE, attr)
          return
        elsif row > 1 && row < rows
          Draw.attrbox(@cell[row][col], Ncurses::ACS_LTEE, Ncurses::ACS_RTEE,
              Ncurses::ACS_LTEE, Ncurses::ACS_RTEE, Ncurses::ACS_HLINE,
              Ncurses::ACS_VLINE, attr)
          return
        elsif row == rows
          Draw.attrbox(@cell[row][col], Ncurses::ACS_LTEE, Ncurses::ACS_RTEE,
              Ncurses::ACS_LLCORNER, Ncurses::ACS_LRCORNER, Ncurses::ACS_HLINE,
              Ncurses::ACS_VLINE, attr)
          return
        end
      end
      if @col_space == 0 && @row_space != 0
        if col == 1
          Draw.attrbox(@cell[row][col], Ncurses::ACS_ULCORNER,
              Ncurses::ACS_TTEE, Ncurses::ACS_LLCORNER, Ncurses::ACS_BTEE,
              Ncurses::ACS_HLINE, Ncurses::ACS_VLINE, attr)
          return
        elsif col > 1 && col < cols
          Draw.attrbox(@cell[row][col], Ncurses::ACS_TTEE, Ncurses::ACS_TTEE,
              Ncurses::ACS_BTEE, Ncurses::ACS_BTEE, Ncurses::ACS_HLINE,
              Ncurses::ACS_VLINE, attr)
          return
        elsif col == cols
          Draw.attrbox(@cell[row][col], Ncurses::ACS_TTEE,
              Ncurses::ACS_URCORNER,Ncurses::ACS_BTEE, Ncurses::ACS_LRCORNER,
              Ncurses::ACS_HLINE, Ncurses::ACS_VLINE, attr)
          return
        end
      end

      # Start drawing the matrix.
      if row == 1
        if col == 1
          # Draw the top left corner
          Draw.attrbox(@cell[row][col], Ncurses::ACS_ULCORNER,
              Ncurses::ACS_TTEE, Ncurses::ACS_LTEE, Ncurses::ACS_PLUS,
              Ncurses::ACS_HLINE, Ncurses::ACS_VLINE, attr)
        elsif col > 1 && col < cols
          # Draw the top middle box
          Draw.attrbox(@cell[row][col], Ncurses::ACS_TTEE, Ncurses::ACS_TTEE,
              Ncurses::ACS_PLUS, Ncurses::ACS_PLUS, Ncurses::ACS_HLINE,
              Ncurses::ACS_VLINE, attr)
        elsif col == cols
          # Draw the top right corner
          Draw.attrbox(@cell[row][col], Ncurses::ACS_TTEE,
              Ncurses::ACS_URCORNER, Ncurses::ACS_PLUS, Ncurses::ACS_RTEE,
              Ncurses::ACS_HLINE, Ncurses::ACS_VLINE, attr)
        end
      elsif row > 1 && row < rows
        if col == 1
          # Draw the middle left box
          Draw.attrbox(@cell[row][col], Ncurses::ACS_LTEE, Ncurses::ACS_PLUS,
              Ncurses::ACS_LTEE, Ncurses::ACS_PLUS, Ncurses::ACS_HLINE,
              Ncurses::ACS_VLINE, attr)
        elsif col > 1 && col < cols
          # Draw the middle box
          Draw.attrbox(@cell[row][col], Ncurses::ACS_PLUS, Ncurses::ACS_PLUS,
              Ncurses::ACS_PLUS, Ncurses::ACS_PLUS, Ncurses::ACS_HLINE,
              Ncurses::ACS_VLINE, attr)
        elsif col == cols
          # Draw the middle right box
          Draw.attrbox(@cell[row][col], Ncurses::ACS_PLUS, Ncurses::ACS_RTEE,
              Ncurses::ACS_PLUS, Ncurses::ACS_RTEE, Ncurses::ACS_HLINE,
              Ncurses::ACS_VLINE, attr)
        end
      elsif row == rows
        if col == 1
          # Draw the bottom left corner
          Draw.attrbox(@cell[row][col], Ncurses::ACS_LTEE, Ncurses::ACS_PLUS,
              Ncurses::ACS_LLCORNER, Ncurses::ACS_BTEE, Ncurses::ACS_HLINE,
              Ncurses::ACS_VLINE, attr)
        elsif col > 1 && col < cols
          # Draw the bottom middle box
          Draw.attrbox(@cell[row][col], Ncurses::ACS_PLUS, Ncurses::ACS_PLUS,
              Ncurses::ACS_BTEE, Ncurses::ACS_BTEE, Ncurses::ACS_HLINE,
              Ncurses::ACS_VLINE, attr)
        elsif col == cols
          # Draw the bottom right corner
          Draw.attrbox(@cell[row][col], Ncurses::ACS_PLUS, Ncurses::ACS_RTEE,
              Ncurses::ACS_BTEE, Ncurses::ACS_LRCORNER, Ncurses::ACS_HLINE,
              Ncurses::ACS_VLINE, attr)
        end
      end

      self.focusCurrent
    end

    def drawEachColTitle
      (1..@vcols).each do |x|
        unless @cell[0][x].nil?
          Ncurses.werase @cell[0][x]

          Draw.writeChtype(@cell[0][x],
                           @coltitle_pos[@lcol + x - 1], 0,
                           @coltitle[@lcol + x - 1],
                           RNDK::HORIZONTAL, 0,
                           @coltitle_len[@lcol + x - 1])

          Ncurses.wrefresh @cell[0][x]
        end
      end
    end

    def drawEachRowTitle
      (1..@vrows).each do |x|
        unless @cell[x][0].nil?
          Ncurses.werase @cell[x][0]

          Draw.writeChtype(@cell[x][0],
                           @rowtitle_pos[@trow + x - 1], 1,
                           @rowtitle[@trow + x - 1],
                           RNDK::HORIZONTAL,
                           0,
                           @rowtitle_len[@trow + x - 1])

          Ncurses.wrefresh @cell[x][0]
        end
      end
    end

    def drawEachCell
      # Fill in the cells.
      (1..@vrows).each do |x|
        (1..@vcols).each do |y|
          self.drawCell(x,
                        y,
                        @trow + x - 1,
                        @lcol + y - 1,
                        Ncurses::A_NORMAL,
                        @box_cell)
        end
      end
    end

    def drawCurCell
      self.drawCell(@crow, @ccol, @row, @col, Ncurses::A_NORMAL, @box_cell)
    end

    def drawOldCell
      self.drawCell(@oldcrow, @oldccol, @oldvrow, @oldvcol, Ncurses::A_NORMAL, @box_cell)
    end

    # This function draws the matrix widget.
    def draw(box)
      # Did we ask for a shadow?
      unless @shadow_win.nil?
        Draw.drawShadow(@shadow_win)
      end

      # Should we box the matrix?
      if box
        Draw.drawObjBox(@win, self)
      end

      self.drawTitle(@win)

      Ncurses.wrefresh @win

      self.drawEachColTitle
      self.drawEachRowTitle
      self.drawEachCell
      self.focusCurrent
    end

    # This function destroys the matrix widget.
    def destroy
      self.cleanTitle

      # Clear the matrix windows.
      RNDK.deleteCursesWindow(@cell[0][0])
      (1..@vrows).each { |x| RNDK.deleteCursesWindow @cell[x][0] }
      (1..@vcols).each { |x| RNDK.deleteCursesWindow @cell[0][x] }

      (1..@vrows).each do |x|
        (1..@vcols).each do |y|
          RNDK.deleteCursesWindow @cell[x][y]
        end
      end

      RNDK.deleteCursesWindow @shadow_win
      RNDK.deleteCursesWindow @win

      # Clean the key bindings.
      self.clean_bindings(:MATRIX)

      # Unregister this object.
      RNDK::Screen.unregister(:MATRIX, self)
    end

    # This function erases the matrix widget from the screen.
    def erase
      if self.valid_widget?
        # Clear the matrix cells.
        RNDK.eraseCursesWindow @cell[0][0]

        (1..@vrows).each { |x| RNDK.eraseCursesWindow @cell[x][0] }
        (1..@vcols).each { |x| RNDK.eraseCursesWindow @cell[0][x] }

        (1..@vrows).each do |x|
          (1..@vcols).each do |y|
            RNDK.eraseCursesWindow @cell[x][y]
          end
        end

        RNDK.eraseCursesWindow @shadow_win
        RNDK.eraseCursesWindow @win
      end
    end

    # Set the callback function
    def setCB(callback)
      @callbackfn = callback
    end

    # This function sets the values of the matrix widget.
    def setCells(info, rows, maxcols, sub_size)
      if rows > @rows
        rows = @rows
      end

      # Copy in the new info.
      (1..rows).each do |x|
        (1..@cols).each do |y|
          if x <= rows && y <= sub_size[x]
            @info[x][y] = @info[x][y][0..[@colwidths[y], @info[x][y].size].min]
          else
            self.cleanCell(x, y)
          end
        end
      end
    end

    # This cleans out the information cells in the matrix widget.
    def clean
      (1..@rows).each do |x|
        (1..@cols).each do |y|
          self.cleanCell(x, y)
        end
      end
    end

    # This cleans one cell in the matrix widget.
    def cleanCell(row, col)
      if row > 0 && row <= @rows && col > col <= @cols
        @info[row][col] = ''
      end
    end

    # This allows us to hyper-warp to a cell
    def jumpToCell(row, col)
      new_row = row
      new_col = col

      # Only create the row scale if needed.
      if (row == -1) || (row > @rows)
        # Create the row scale widget.
        scale = RNDK::SCALE.new(@screen, RNDK::CENTER, RNDK::CENTER,
            '<C>Jump to which row.', '</5/B>Row: ', Ncurses::A_NORMAL,
            5, 1, 1, @rows, 1, 1, true, false)

        # Activate the scale and get the row.
        new_row = scale.activate([])
        scale.destroy
      end

      # Only create the column scale if needed.
      if (col == -1) || (col > @cols)
        # Create the column scale widget.
        scale = RNDK::SCALE.new(@screen, RNDK::CENTER, RNDK::CENTER,
            '<C>Jump to which column', '</5/B>Col: ', Ncurses::A_NORMAL,
            5, 1, 1, @cols, 1, 1, true, false)

        # Activate the scale and get the column.
        new_col = scale.activate([])
        scale.destroy
      end

      # Hyper-warp....
      if new_row != @row || @new_col != @col
        return self.moveToCell(new_row, new_col)
      else
        return 1
      end
    end

    # This allows us to move to a given cell.
    def moveToCell(newrow, newcol)
      row_shift = newrow - @row
      col_shift = newcol - @col

      # Make sure we aren't asking to move out of the matrix.
      if newrow > @rows || newcol > @cols || newrow <= 0 || newcol <= 0
        return 0
      end

      # Did we move up/down?
      if row_shift > 0
        # We are moving down
        if @vrows == @cols
          @trow = 1
          @crow = newrow
          @row = newrow
        else
          if row_shift + @vrows < @rows
            # Just shift down by row_shift
            @trow += row_shift
            @crow = 1
            @row += row_shift
          else
            # We need to munge the values
            @trow = @rows - @vrows + 1
            @crow = row_shift + @vrows - @rows + 1
            @row = newrow
          end
        end
      elsif row_shift < 0
        # We are moving up.
        if @vrows == @rows
          @trow = 1
          @row = newrow
          @crow = newrow
        else
          if row_shift + @vrows > 1
            # Just shift up by row_shift...
            @trow += row_shift
            @row += row_shift
            @crow = 1
          else
            # We need to munge the values
            @trow = 1
            @crow = 1
            @row = 1
          end
        end
      end

      # Did we move left/right?
      if col_shift > 0
        # We are moving right.
        if @vcols == @cols
          @lcol = 1
          @ccol = newcol
          @col = newcol
        else
          if col_shift + @vcols < @cols
            @lcol += col_shift
            @ccol = 1
            @col += col_shift
          else
            # We need to munge with the values
            @lcol = @cols - @vcols + 1
            @ccol = col_shift + @vcols - @cols + 1
            @col = newcol
          end
        end
      elsif col_shift < 0
        # We are moving left.
        if @vcols == @cols
          @lcol = 1
          @col = newcol
          @ccol = newcol
        else
          if col_shift + @vcols > 1
            # Just shift left by col_shift
            @lcol += col_shift
            @col += col_shift
            @ccol = 1
          else
            @lcol = 1
            @col = 1
            @ccol = 1
          end
        end
      end

      # Keep the 'old' values around for redrawing sake.
      @oldcrow = @crow
      @oldccol = @ccol
      @oldvrow = @row
      @oldvcol = @col

      return 1
    end

    # This redraws the titles indicated...
    def redrawTitles(row_titles, col_titles)
      # Redraw the row titles.
      if row_titles
        self.drawEachRowTitle
      end

      # Redraw the column titles.
      if col_titles
        self.drawEachColTitle
      end
    end

    # This sets the value of a matrix cell.
    def setCell(row, col, value)
      # Make sure the row/col combination is within the matrix.
      if row > @rows || cols > @cols || row <= 0 || col <= 0
        return -1
      end

      self.cleanCell(row, col)
      @info[row][col] = value[0...[@colwidths[col], value.size].min]
      return 1
    end

    # This gets the value of a matrix cell.
    def getCell(row, col)
      # Make sure the row/col combination is within the matrix.
      if row > @rows || col > @cols || row <= 0 || col <= 0
        return 0
      end
      return @info[row][col]
    end

    def CurMatrixCell
      return @cell[@crow][@ccol]
    end

    def CurMatrixInfo
      return @info[@trow + @crow - 1][@lcol + @ccol - 1]
    end

    def focusCurrent
      Draw.attrbox(self.CurMatrixCell,
                   Ncurses::ACS_ULCORNER,
                   Ncurses::ACS_URCORNER,
                   Ncurses::ACS_LLCORNER,
                   Ncurses::ACS_LRCORNER,
                   Ncurses::ACS_HLINE,
                   Ncurses::ACS_VLINE,
                   Ncurses::A_BOLD)

      Ncurses.wrefresh self.CurMatrixCell
      self.highlightCell
    end

    # This returns the current row/col cell
    def getCol
      return @col
    end

    def getRow
      return @row
    end

    # This sets the background attribute of the widget.
    def set_bg_attrib(attrib)
      Ncurses.wbkgd(@win, attrib)

      # TODO what the hell?
      (0..@vrows).each do |x|
        (0..@vcols).each do |y|
          # wbkgd (MATRIX_CELL (widget, x, y), attrib);
        end
      end
    end

    def focus
      self.draw(@box)
    end

    def unfocus
      self.draw(@box)
    end

    def position
      super(@win)
    end

    def object_type
      :MATRIX
    end
  end
end
