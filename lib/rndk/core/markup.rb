# # RNDK String Markup
#
# RNDK has special formatting commands which can be included
# in any String which add highlights, justification, or even
# colors to a basic String.
#
# These attributes, once set, remain in effect until changed
# explicitly, or until the end of the string.
#
# ## Colors
#
# RNDK has the capability to display colors in almost any text
# inside a Widget.
#
# To turn on colors, the function #initCDKColor has to be called. When
# this function is called 64 color pairs are created.  Normally the
# color pairs are accessed via the COLOR_PAIR macro.  You can still do
# this, but creating a string with multiple colors gets terribly
# difficult.  That is why the color commands were created.
#
# The color settings are stored directly in the string.  When the
# widget is created or activated, the string is converted to take
# advan- tage of any color commands in the string.  To turn on a color
# pair insert </XX> into the string; where XX is a numeric value from
# 0 to 64.  Color pair 0 is the standard default color pair for the
# screen.  To turn off a color pair use the format command <!XX> where
# XX is a numeric value from 0 to 64.
#
# For example:
#
#     "</31>This line should have a yellow foreground and a cyan background.<!31>"
#     "</05>This line should have a white  foreground and a blue background.<!05>"
#     "</26>This line should have a yellow foreground and a red  background.<!26>"
#     "<C>This line should be set to whatever the screen default is."
#
# ## Attributes
#
# RNDK also provides attribute commands which allow different
# character attributes to be displayed in a Widget.
#
# To use a character attribute the format command is `</X>` where X is
# one of several command characters.  To turn a attribute off use the
# command `<!X>`.
#
# Here's the command characters supported:
#
# B:: Bold
# U:: Underline
# K:: Blink
# R:: Reverse
# S:: Standout
# D:: Dim
# N:: Normal
#
# For example:
#
#     "</B/31>Bold text        yellow foreground / blue background.<!31>"
#     "</U/05>Underlined text  white  foreground / blue background.<!05>"
#     "</K/26>Blinking text    yellow foreground / red  background.<!26>"
#     "<C>This line uses the screen default colors."
#
# ## Justification
#
# Justification commands can **left justify**, **right justify**, or
# **center** a string of text.
#
# A format command must be at the **beginning** of the string.
#
# To use a justification format in a string the command `<X>` is used.
#
# Format commands:
#
# <L>::   Left Justified. Default if not stated.
# <C>::   Centered text.
# <R>::   Right justified.
# <I=X>:: Indent the line X characters.
# <B=X>:: Bullet. X is the bullet string to use.
# <F=X>:: Links in a file where X is  the  filename.  This works only with the viewer widget.
#
# For example:
#
#     "<R></B/31>This line should have a yellow foreground and a blue background.<!31>"
#     "</U/05>This line should have a white  foreground and a blue background.<!05>"
#     "<B=+>This is a bullet."
#     "<I=10>This is indented 10 characters."
#     "<C>This line should be set to whatever the screen default is."
#
# The bullet format command can take either a single character or a
# string.  The bullet in the above example would look like
#
#     + This is a bullet.
#
# but if we were to use the following command instead
#
#     <B=***>This is a bullet.
#
# it would look like
#
#     *** This is a bullet.
#
# ## Special Drawing Characters
#
# RNDK has a set of special drawing characters which can be inserted
# into any ASCII file.  In order to use a special character the format
# command `<#XXX>` is used.
#
# Special character commands:
#
# <#UL>::           Upper Left Corner
# <#UR>::           Upper Right Corner
# <#LL>::           Lower Left Corner
# <#LR>::           Lower Right Corner
#
# <#LT>::           Left Tee
# <#RT>::           Right Tee
# <#TT>::           Top Tee
# <#BT>::           Bottom Tee
#
# <#HL>::           Horizontal Line
# <#VL>::           Vertical Line
#
# <#PL>::           Plus Sign
# <#PM>::           Plus or Minus Sign
# <#DG>::           Degree Sign
# <#CB>::           Checker Board
# <#DI>::           Diamond
# <#BU>::           Bullet
# <#S1>::           Scan line 1
# <#S9>::           Scan line 9
#
# <#LA>::           Left Arrow
# <#RA>::           Right Arrow
# <#TA>::           Top Arrow
# <#BA>::           Bottom Arrow
#
# The character formats can be repeated using an optional numeric
# repeat value. To repeat a character add the repeat count within
# parentheses to the end of the character format.
#
# The following example draws 10 horizontal-line characters:
#
#     <#HL(10)>
#
# And the most complex example until now. Guess what it does:
#
#     "<C><#UL><#HL(26)><#UR>"
#     "<C><#VL></R>This text should be boxed.<!R><#VL>"
#     "<C><#LL><#HL(26)><#LR>"
#     "<C>While this is not."

module RNDK

  def RNDK.char_of chtype
    (chtype.ord & 255).chr
  end

  # Takes a String full of format markers and translates it
  # into a chtype array.
  #
  # This is better suited to curses because curses uses
  # chtype almost exclusively
  def RNDK.char2Chtype(string, to, align)
    to << 0
    align << LEFT
    result = []

    if string.size > 0
      used = 0

      # The original code makes two passes since it has to pre-allocate space but
      # we should be able to make do with one since we can dynamically size it
      adjust = 0
      attrib = RNDK::Color[:normal]
      last_char = 0
      start = 0
      used = 0
      x = 3

      # Look for an alignment marker.
      if string[0] == L_MARKER
        if string[1] == 'C' && string[2] == R_MARKER
          align[0] = CENTER
          start = 3
        elsif string[1] == 'R' && string[2] == R_MARKER
          align[0] = RIGHT
          start = 3
        elsif string[1] == 'L' && string[2] == R_MARKER
          start = 3
        elsif string[1] == 'B' && string[2] == '='
          # Set the item index value in the string.
          result = [' '.ord, ' '.ord, ' '.ord]

          # Pull out the bullet marker.
          while x < string.size and string[x] != R_MARKER
            result << (string[x].ord | RNDK::Color[:bold])
            x += 1
          end
          adjust = 1

          # Set the alignment variables
          start = x
          used = x
        elsif string[1] == 'I' && string[2] == '='
          from = 3
          x = 0

          while from < string.size && string[from] != Ncurses.R_MARKER
            if RNDK.digit?(string[from])
              adjust = adjust * 10 + string[from].to_i
              x += 1
            end
            from += 1
          end

          start = x + 4
        end
      end

      while adjust > 0
        adjust -= 1
        result << ' '
        used += 1
      end

      # Set the format marker boolean to false
      inside_marker = false

      # Start parsing the character string.
      from = start
      while from < string.size
        # Are we inside a format marker?
        if !inside_marker
          if string[from] == L_MARKER &&
              ['/', '!', '#'].include?(string[from + 1])
            inside_marker = true
          elsif string[from] == "\\" && string[from + 1] == L_MARKER
            from += 1
            result << (string[from].ord | attrib)
            used += 1
            from += 1
          elsif string[from] == "\t"
            begin
              result << ' '
              used += 1
            end while (used & 7).nonzero?
          else
            result << (string[from].ord | attrib)
            used += 1
          end
        else
          case string[from]
          when R_MARKER
            inside_marker = false
          when '#'
            last_char = 0
            case string[from + 2]
            when 'L'
              case string[from + 1]
              when 'L'
                last_char = Ncurses::ACS_LLCORNER
              when 'U'
                last_char = Ncurses::ACS_ULCORNER
              when 'H'
                last_char = Ncurses::ACS_HLINE
              when 'V'
                last_char = Ncurses::ACS_VLINE
              when 'P'
                last_char = Ncurses::ACS_PLUS
              end
            when 'R'
              case string[from + 1]
              when 'L'
                last_char = Ncurses::ACS_LRCORNER
              when 'U'
                last_char = Ncurses::ACS_URCORNER
              end
            when 'T'
              case string[from + 1]
              when 'T'
                last_char = Ncurses::ACS_TTEE
              when 'R'
                last_char = Ncurses::ACS_RTEE
              when 'L'
                last_char = Ncurses::ACS_LTEE
              when 'B'
                last_char = Ncurses::ACS_BTEE
              end
            when 'A'
              case string[from + 1]
              when 'L'
                last_char = Ncurses::ACS_LARROW
              when 'R'
                last_char = Ncurses::ACS_RARROW
              when 'U'
                last_char = Ncurses::ACS_UARROW
              when 'D'
                last_char = Ncurses::ACS_DARROW
              end
            else
              case [string[from + 1], string[from + 2]]
              when ['D', 'I']
                last_char = Ncurses::ACS_DIAMOND
              when ['C', 'B']
                last_char = Ncurses::ACS_CKBOARD
              when ['D', 'G']
                last_char = Ncurses::ACS_DEGREE
              when ['P', 'M']
                last_char = Ncurses::ACS_PLMINUS
              when ['B', 'U']
                last_char = Ncurses::ACS_BULLET
              when ['S', '1']
                last_char = Ncurses::ACS_S1
              when ['S', '9']
                last_char = Ncurses::ACS_S9
              end
            end

            if last_char.nonzero?
              adjust = 1
              from += 2

              if string[from + 1] == '('
                # check for a possible numeric modifier
                from += 2
                adjust = 0

                while from < string.size && string[from] != ')'
                  if RNDK.digit?(string[from])
                    adjust = (adjust * 10) + string[from].to_i
                  end
                  from += 1
                end
              end
            end
            (0...adjust).each do |x|
              result << (last_char | attrib)
              used += 1
            end
          when '/'
            mask = []
            from = RNDK.encodeAttribute(string, from, mask)
            attrib |= mask[0]
          when '!'
            mask = []
            from = RNDK.encodeAttribute(string, from, mask)
            attrib &= ~(mask[0])
          end
        end
        from += 1
      end

      if result.size == 0
        result << attrib
      end
      to[0] = used
    else
      result = []
    end
    return result
  end

  # Compare a regular string to a chtype string
  def RNDK.cmpStrChstr(str, chstr)
    i = 0
    r = 0

    if str.nil? && chstr.nil?
      return 0
    elsif str.nil?
      return 1
    elsif chstr.nil?
      return -1
    end

    while i < str.size && i < chstr.size
      if str[r].ord < chstr[r]
        return -1
      elsif str[r].ord > chstr[r]
        return 1
      end
      i += 1
    end

    if str.size < chstr.size
      return -1
    elsif str.size > chstr.size
      return 1
    else
      return 0
    end
  end

  # This returns a string from a chtype array
  # Formatting codes are omitted.
  def RNDK.chtype2Char(string)
    newstring = ''

    unless string.nil?
      string.each do |char|
        newstring << RNDK.char_of(char)
      end
    end

    return newstring
  end

  # This returns a string from a chtype array
  # Formatting codes are embedded
  def RNDK.chtype2String(string)
    newstring = ''
    unless string.nil?
      need = 0
      (0...string.size).each do |x|
        need = RNDK.decodeAttribute(newstring, need,
                                   x > 0 ? string[x - 1] : 0, string[x])
        newstring << string[x]
      end
    end

    return newstring
  end

  # This takes a string, a field width, and a justification type
  # and returns the adjustment to make, to fill the justification
  # requirement
  def RNDK.justifyString (box_width, mesg_length, justify)

    # make sure the message isn't longer than the width
    # if it is, return 0
    if mesg_length >= box_width
      return 0
    end

    # try to justify the message
    case justify
    when LEFT
      0
    when RIGHT
      box_width - mesg_length
    when CENTER
      (box_width - mesg_length) / 2
    else
      justify
    end
  end

  def RNDK.encodeAttribute (string, from, mask)
    mask << 0
    case string[from + 1]
    when 'B'
      mask[0] = RNDK::Color[:bold]
    when 'D'
      mask[0] = RNDK::Color[:dim]
    when 'K'
      mask[0] = RNDK::Color[:blink]
    when 'R'
      mask[0] = RNDK::Color[:reverse]
    when 'S'
      mask[0] = RNDK::Color[:standout]
    when 'U'
      mask[0] = RNDK::Color[:underline]
    end

    if mask[0] != 0
      from += 1
    elsif RNDK.digit?(string[from+1]) and RNDK.digit?(string[from + 2])
      if Ncurses.has_colors
        # XXX: Only checks if terminal has colours not if colours are started
        pair = string[from + 1..from + 2].to_i
        mask[0] = Ncurses.COLOR_PAIR(pair)
      else
        mask[0] = Ncurses.A_BOLD
      end

      from += 2
    elsif RNDK.digit?(string[from + 1])
      if Ncurses.has_colors
        # XXX: Only checks if terminal has colours not if colours are started
        pair = string[from + 1].to_i
        mask[0] = Ncurses.COLOR_PAIR(pair)
      else
        mask[0] = Ncurses.A_BOLD
      end

      from += 1
    end

    return from
  end

  # The reverse of encodeAttribute
  # Well, almost.  If attributes such as bold and underline are combined in the
  # same string, we do not necessarily reconstruct them in the same order.
  # Also, alignment markers and tabs are lost.
  def RNDK.decodeAttribute (string, from, oldattr, newattr)
    table = {
      'B' => RNDK::Color[:bold],
      'D' => RNDK::Color[:dim],
      'K' => RNDK::Color[:blink],
      'R' => RNDK::Color[:reverse],
      'S' => RNDK::Color[:standout],
      'U' => RNDK::Color[:underline]
    }

    result = if string.nil? then '' else string end
    base_len = result.size
    tmpattr = oldattr & RNDK::Color[:extract]

    newattr &= RNDK::Color[:extract]
    if tmpattr != newattr
      while tmpattr != newattr
        found = false
        table.keys.each do |key|
          if (table[key] & tmpattr) != (table[key] & newattr)
            found = true
            result << RNDK::L_MARKER
            if (table[key] & tmpattr).nonzero?
              result << '!'
              tmpattr &= ~(table[key])
            else
              result << '/'
              tmpattr |= table[key]
            end
            result << key
            break
          end
        end
        # XXX: Only checks if terminal has colours not if colours are started
        if Ncurses.has_colors
          if (tmpattr & Ncurses::A_COLOR) != (newattr & Ncurses::A_COLOR)
            oldpair = Ncurses.PAIR_NUMBER(tmpattr)
            newpair = Ncurses.PAIR_NUMBER(newattr)
            if !found
              found = true
              result << RNDK::L_MARKER
            end
            if newpair.zero?
              result << '!'
              result << oldpair.to_s
            else
              result << '/'
              result << newpair.to_s
            end
            tmpattr &= ~(Ncurses::A_COLOR)
            newattr &= ~(Ncurses::A_COLOR)
          end
        end

        if found
          result << RNDK::R_MARKER
        else
          break
        end
      end
    end

    return from + result.size - base_len
  end

end

