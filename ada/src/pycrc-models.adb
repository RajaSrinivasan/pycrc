--  pycrc -- parameterisable CRC calculation utility and Ada source generator.
--
--  Copyright (c) 2006-2017  Thomas Pircher  <tehpeh-web@tty1.net>
--
--  Permission is hereby granted, free of charge, to any person obtaining a copy
--  of this software and associated documentation files (the "Software"), to
--  deal in the Software without restriction, including without limitation the
--  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
--  sell copies of the Software, and to permit persons to whom the Software is
--  furnished to do so, subject to the following conditions:
--
--  The above copyright notice and this permission notice shall be included in
--  all copies or substantial portions of the Software.
--
--  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
--  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
--  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
--  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
--  IN THE SOFTWARE.

package body PyCRC.Models
  with SPARK_Mode
is

   function To_String (Name : Model_Name) return String is
     (Name.Text (1 .. Name.Length));

   function To_Name (Text : String) return Model_Name with
     Pre  => Text'First = 1 and then Text'Length <= Max_Model_Name,
     Post => To_Name'Result.Length = Text'Length
   is
      Result : Model_Name := (Length => Text'Length, Text => [others => ' ']);
   begin
      for I in 1 .. Text'Length loop
         Result.Text (I) := Text (I);
      end loop;
      return Result;
   end To_Name;

   function Lower_Char (C : Character) return Character is
     (if C in 'A' .. 'Z'
      then Character'Val
        (Character'Pos (C) - Character'Pos ('A') + Character'Pos ('a'))
      else C)
   with
     Post =>
       (if C in 'A' .. 'Z'
        then Lower_Char'Result in 'a' .. 'z'
        else Lower_Char'Result = C);

   function Lower (Text : String) return String with
     Post => Lower'Result'First = Text'First
       and then Lower'Result'Last = Text'Last
   is
      Result : String (Text'Range);
   begin
      for I in Text'Range loop
         Result (I) := Lower_Char (Text (I));
      end loop;
      return Result;
   end Lower;

   function M
     (Name        : String;
      Width       : Width_Type;
      Poly        : Interfaces.Unsigned_64;
      Reflect_In  : Boolean;
      Xor_In      : Interfaces.Unsigned_64;
      Reflect_Out : Boolean;
      Xor_Out     : Interfaces.Unsigned_64;
      Check       : Interfaces.Unsigned_64) return Model
   with
     Pre  => Name'First = 1 and then Name'Length <= Max_Model_Name
       and then Poly <= Bits_Mask (Width)
       and then Xor_In <= Bits_Mask (Width)
       and then Xor_Out <= Bits_Mask (Width)
       and then Check <= Bits_Mask (Width)
   is
   begin
      return
        (Name        => To_Name (Name),
         Width       => Width,
         Poly        => Poly,
         Reflect_In  => Reflect_In,
         Xor_In      => Xor_In,
         Reflect_Out => Reflect_Out,
         Xor_Out     => Xor_Out,
         Check       => Check);
   end M;

   --  The catalogue matches src/pycrc/models.py, including the check value
   --  of the ASCII string "123456789".
   Catalog : constant array (Positive range <>) of Model :=
     [M ("crc-5", 5, 16#05#, True, 16#1F#, True, 16#1F#, 16#19#),
      M ("crc-8", 8, 16#07#, False, 16#00#, False, 16#00#, 16#F4#),
      M ("dallas-1-wire", 8, 16#31#, True, 16#00#, True, 16#00#, 16#A1#),
      M ("crc-12-3gpp", 12, 16#80F#, False, 16#00#, True, 16#00#, 16#DAF#),
      M ("crc-15", 15, 16#4599#, False, 16#00#, False, 16#00#, 16#59E#),
      M ("crc-16", 16, 16#8005#, True, 16#0000#, True, 16#0000#, 16#BB3D#),
      M ("crc-16-usb", 16, 16#8005#, True, 16#FFFF#, True, 16#FFFF#, 16#B4C8#),
      M ("crc-16-modbus", 16, 16#8005#, True, 16#FFFF#, True, 16#0000#,
         16#4B37#),
      M ("crc-16-genibus", 16, 16#1021#, False, 16#FFFF#, False, 16#FFFF#,
         16#D64E#),
      M ("crc-16-ccitt", 16, 16#1021#, False, 16#1D0F#, False, 16#0000#,
         16#E5CC#),
      M ("r-crc-16", 16, 16#0589#, False, 16#0000#, False, 16#0001#, 16#007E#),
      M ("kermit", 16, 16#1021#, True, 16#0000#, True, 16#0000#, 16#2189#),
      M ("x-25", 16, 16#1021#, True, 16#FFFF#, True, 16#FFFF#, 16#906E#),
      M ("xmodem", 16, 16#1021#, False, 16#0000#, False, 16#0000#, 16#31C3#),
      M ("zmodem", 16, 16#1021#, False, 16#0000#, False, 16#0000#, 16#31C3#),
      M ("crc-24", 24, 16#864CFB#, False, 16#B704CE#, False, 16#000000#,
         16#21CF02#),
      M ("crc-32", 32, 16#04C11DB7#, True, 16#FFFFFFFF#, True, 16#FFFFFFFF#,
         16#CBF43926#),
      M ("crc-32c", 32, 16#1EDC6F41#, True, 16#FFFFFFFF#, True, 16#FFFFFFFF#,
         16#E3069283#),
      M ("crc-32-mpeg", 32, 16#04C11DB7#, False, 16#FFFFFFFF#, False, 16#0#,
         16#0376E6E7#),
      M ("crc-32-bzip2", 32, 16#04C11DB7#, False, 16#FFFFFFFF#, False,
         16#FFFFFFFF#, 16#FC891918#),
      M ("posix", 32, 16#04C11DB7#, False, 16#0#, False, 16#FFFFFFFF#,
         16#765E7680#),
      M ("jam", 32, 16#04C11DB7#, True, 16#FFFFFFFF#, True, 16#0#,
         16#340BC6D9#),
      M ("xfer", 32, 16#AF#, False, 16#0#, False, 16#0#, 16#BD0BE338#),
      M ("crc-64", 64, 16#1B#, True, 16#0#, True, 16#0#, 16#46A5A9388A5BEFFE#),
      M ("crc-64-jones", 64, 16#AD93D23594C935A9#, True,
         16#FFFFFFFFFFFFFFFF#, True, 16#0#, 16#CAA717168609F281#),
      M ("crc-64-xz", 64, 16#42F0E1EBA9EA3693#, True,
         16#FFFFFFFFFFFFFFFF#, True, 16#FFFFFFFFFFFFFFFF#,
         16#995DC9BBDF1939FA#)];

   function Count return Positive is (Catalog'Length);

   function At_Index (Index : Positive) return Model is (Catalog (Index));

   procedure Lookup (Name : String; Item : out Model; Found : out Boolean) is
      Wanted : constant String := Lower (Name);
   begin
      Item := Catalog (Catalog'First);
      Found := False;
      for Index in Catalog'Range loop
         if Wanted = To_String (Catalog (Index).Name) then
            Item := Catalog (Index);
            Found := True;
            return;
         end if;
      end loop;
   end Lookup;

   function Names (Separator : String := ", ") return String
   with SPARK_Mode => Off
   is
      function Join (Index : Positive) return String is
         Piece : constant String := To_String (Catalog (Index).Name);
      begin
         if Index = Catalog'Last then
            return Piece;
         else
            return Piece & Separator & Join (Index + 1);
         end if;
      end Join;
   begin
      return Join (Catalog'First);
   end Names;

end PyCRC.Models;
