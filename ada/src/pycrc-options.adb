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

with Ada.Characters.Handling;
with Ada.Command_Line;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with PyCRC.Models;

package body PyCRC.Options is

   use Ada.Strings.Unbounded;
   use Interfaces;

   type U128 is record
      Lo : Unsigned_64 := 0;
      Hi : Unsigned_64 := 0;
   end record;

   function Is_Zero (Value : U128) return Boolean is
     (Value.Lo = 0 and then Value.Hi = 0);

   function Shl128
     (Value : U128; Amount : Natural; Overflow : in out Boolean) return U128
   is
   begin
      if Amount = 0 then
         return Value;
      elsif Amount >= 128 then
         Overflow := Overflow or else not Is_Zero (Value);
         return (0, 0);
      elsif Amount = 64 then
         if Value.Hi /= 0 then
            Overflow := True;
         end if;
         return (Lo => 0, Hi => Value.Lo);
      elsif Amount > 64 then
         if Value.Hi /= 0
           or else Shift_Right (Value.Lo, 128 - Amount) /= 0
         then
            Overflow := True;
         end if;
         return (Lo => 0, Hi => Shift_Left (Value.Lo, Amount - 64));
      else
         if Shift_Right (Value.Hi, 64 - Amount) /= 0 then
            Overflow := True;
         end if;
         return
           (Lo => Shift_Left (Value.Lo, Amount),
            Hi =>
              Shift_Left (Value.Hi, Amount)
              or Shift_Right (Value.Lo, 64 - Amount));
      end if;
   end Shl128;

   function Add_Small
     (Value : U128; Digit : Unsigned_64; Overflow : in out Boolean) return U128
   is
      Lo    : constant Unsigned_64 := Value.Lo + Digit;
      Carry : constant Unsigned_64 :=
        (if Digit > 0 and then Lo < Value.Lo then 1 else 0);
      Hi    : Unsigned_64;
   begin
      if Carry = 1 and then Value.Hi = Unsigned_64'Last then
         Overflow := True;
         Hi := 0;
      else
         Hi := Value.Hi + Carry;
      end if;
      return (Lo => Lo, Hi => Hi);
   end Add_Small;

   function Shr128 (Value : U128; Amount : Natural) return U128 is
   begin
      if Amount = 0 then
         return Value;
      elsif Amount >= 128 then
         return (0, 0);
      elsif Amount >= 64 then
         return (Lo => Shift_Right (Value.Hi, Amount - 64), Hi => 0);
      else
         return
           (Lo =>
              Shift_Right (Value.Lo, Amount)
              or Shift_Left (Value.Hi, 64 - Amount),
            Hi => Shift_Right (Value.Hi, Amount));
      end if;
   end Shr128;

   function Too_Wide (Value : U128; Width : Width_Type) return Boolean is
      Shifted : constant U128 := Shr128 (Value, Width + 1);
   begin
      return not Is_Zero (Shifted);
   end Too_Wide;

   function Add128
     (Left, Right : U128; Overflow : in out Boolean) return U128
   is
      Lo    : constant Unsigned_64 := Left.Lo + Right.Lo;
      Carry : constant Unsigned_64 := (if Lo < Left.Lo then 1 else 0);
      Hi    : Unsigned_64 := Left.Hi + Right.Hi;
   begin
      if Hi < Left.Hi then
         Overflow := True;
      end if;
      if Carry = 1 then
         if Hi = Unsigned_64'Last then
            Overflow := True;
            Hi := 0;
         else
            Hi := Hi + 1;
         end if;
      end if;
      return (Lo => Lo, Hi => Hi);
   end Add128;

   function Parse_U128 (Option, Text : String) return U128 is
      use Ada.Characters.Handling;
      Overflow : Boolean := False;
      Value    : U128 := (0, 0);
      Pos      : Natural := Text'First;
      Hex      : Boolean := False;

      procedure Invalid with No_Return;
      procedure Invalid is
      begin
         Die ("option " & Option & ": invalid integer or hexadecimal value: "
              & Text);
      end Invalid;
   begin
      if Text'Length = 0 then
         Invalid;
      end if;
      if Text (Pos) = '+' then
         Pos := Pos + 1;
         if Pos > Text'Last then
            Invalid;
         end if;
      end if;
      if Pos + 1 <= Text'Last
        and then Text (Pos) = '0'
        and then (Text (Pos + 1) = 'x' or else Text (Pos + 1) = 'X')
      then
         Hex := True;
         Pos := Pos + 2;
         if Pos > Text'Last then
            Invalid;
         end if;
      end if;

      while Pos <= Text'Last loop
         declare
            C     : constant Character := Text (Pos);
            Digit : Unsigned_64;
         begin
            if Hex then
               if C in '0' .. '9' then
                  Digit := Character'Pos (C) - Character'Pos ('0');
               elsif C in 'a' .. 'f' or else C in 'A' .. 'F' then
                  Digit :=
                    Unsigned_64
                      (Character'Pos (To_Lower (C)) - Character'Pos ('a') + 10);
               else
                  Invalid;
               end if;
               Value := Shl128 (Value, 4, Overflow);
            else
               if C not in '0' .. '9' then
                  Invalid;
               end if;
               Digit := Character'Pos (C) - Character'Pos ('0');
               declare
                  Times_8 : constant U128 := Shl128 (Value, 3, Overflow);
                  Times_2 : constant U128 := Shl128 (Value, 1, Overflow);
               begin
                  Value := Add128 (Times_8, Times_2, Overflow);
               end;
            end if;
            Value := Add_Small (Value, Digit, Overflow);
         end;
         Pos := Pos + 1;
      end loop;

      if Overflow then
         Die ("option " & Option & ": integer too large: " & Text);
      end if;
      return Value;
   end Parse_U128;

   function Parse_Bool (Option, Text : String) return Boolean is
      use Ada.Characters.Handling;
   begin
      if To_Lower (Text) = "true" then
         return True;
      elsif To_Lower (Text) = "false" then
         return False;
      elsif Text'Length > 0 and then (for all C of Text => Is_Digit (C)) then
         return (for some C of Text => C /= '0');
      else
         Die ("option " & Option & ": invalid boolean value: " & Text);
      end if;
   end Parse_Bool;

   function Decimal_Image (Value : Natural) return String is
      Text : constant String := Value'Image;
   begin
      return Text (Text'First + 1 .. Text'Last);
   end Decimal_Image;

   procedure Print_Help is
      use Ada.Text_IO;
   begin
      Put_Line ("Usage: pycrc [OPTIONS]");
      Put_Line ("");
      Put_Line ("Calculate the checksum of a string or hexadecimal data:");
      Put_Line ("    pycrc [model] --check-string ""123456789""");
      Put_Line ("    pycrc [model] --check-hexstring ""313233343536373839""");
      Put_Line ("");
      Put_Line ("Calculate the checksum of a file:");
      Put_Line ("    pycrc [model] --check-file filename");
      Put_Line ("");
      Put_Line ("Generate an Ada package and write it to filename:");
      Put_Line ("    pycrc [model] --algorithm tbl --generate ads -o crc.ads");
      Put_Line ("    pycrc [model] --algorithm tbl --generate adb -o crc.adb");
      Put_Line ("");
      Put_Line ("The model is selected with --model or by specifying");
      Put_Line ("--width --poly --reflect-in --xor-in --reflect-out --xor-out.");
      Put_Line ("");
      Put_Line ("Options:");
      Put_Line ("  -h, --help              show this help and exit");
      Put_Line ("  --version               show " & Version_String & " and exit");
      Put_Line ("  -v, --verbose           print the CRC parameters");
      Put_Line ("  --check-string STRING   checksum of a string "
                & "(default: '123456789')");
      Put_Line ("  --check-hexstring STRING");
      Put_Line ("                          checksum of a hexadecimal byte string");
      Put_Line ("  --check-file FILE       checksum of a file");
      Put_Line ("  --generate CODE         write Ada source; CODE is one of");
      Put_Line ("                          {ads, adb, main, table}");
      Put_Line ("                          (h, c and c-main select ads, adb and main)");
      Put_Line ("  --algorithm ALGO        {bit-by-bit, bbb, bit-by-bit-fast, bbf,");
      Put_Line ("                          table-driven, tbl, all}");
      Put_Line ("  --model MODEL           parameter set; one of");
      Put_Line ("                          {" & Models.Names & "}");
      Put_Line ("  --width NUM             width of the CRC register");
      Put_Line ("  --poly HEX              polynomial");
      Put_Line ("  --reflect-in BOOL       reflect input octets");
      Put_Line ("  --xor-in HEX            initial value");
      Put_Line ("  --reflect-out BOOL      reflect the result before xor-out");
      Put_Line ("  --xor-out HEX           final xor value");
      Put_Line ("  --table-idx-width NUM   table index width {1, 2, 4, 8}");
      Put_Line ("  --slice-by NUM          accepted and ignored (not implemented)");
      Put_Line ("  --force-poly            allow an even or oversized polynomial");
      Put_Line ("  --symbol-prefix STRING  Ada package name (default: CRC)");
      Put_Line ("  --include-file UNIT     extra with-clause on the spec");
      Put_Line ("  --crc-type STRING       ignored (C-specific)");
      Put_Line ("  --std STD               ignored (C-specific)");
      Put_Line ("  -o, --output FILE       write generated source to FILE");
   end Print_Help;

   function Starts_With (Text, Prefix : String) return Boolean is
     (Text'Length >= Prefix'Length
      and then Text (Text'First .. Text'First + Prefix'Length - 1) = Prefix);

   function Long_Name (Arg : String) return String is
      Eq : constant Natural := Ada.Strings.Fixed.Index (Arg, "=");
   begin
      if Eq = 0 then
         return Arg;
      else
         return Arg (Arg'First .. Eq - 1);
      end if;
   end Long_Name;

   function Parse return Settings is
      use Ada.Command_Line;

      Opt            : Settings;
      I              : Natural := 1;
      Action_Count   : Natural := 0;
      Algorithm_Text : Unbounded_String := To_Unbounded_String ("all");
      Extra          : Unbounded_String;
      Poly_Raw       : U128 := (0, 0);
      Xor_In_Raw     : U128 := (0, 0);
      Xor_Out_Raw    : U128 := (0, 0);
      Saw_Slice      : Boolean := False;

      function Take_Value (Arg : String) return String is
      begin
         declare
            Eq : constant Natural := Ada.Strings.Fixed.Index (Arg, "=");
         begin
            if Eq /= 0 then
               return Arg (Eq + 1 .. Arg'Last);
            end if;
         end;
         if I >= Argument_Count then
            Die ("option " & Long_Name (Arg) & ": missing argument");
         end if;
         I := I + 1;
         return Argument (I);
      end Take_Value;

      procedure Note_Action is
      begin
         Action_Count := Action_Count + 1;
      end Note_Action;

      function Exactly_One (Alg : Algorithm_Selection) return Boolean is
         N : Natural := 0;
      begin
         if Alg.Bit_By_Bit then
            N := N + 1;
         end if;
         if Alg.Bit_By_Bit_Fast then
            N := N + 1;
         end if;
         if Alg.Table_Driven then
            N := N + 1;
         end if;
         return N = 1;
      end Exactly_One;
   begin
      Opt.Check_String := To_Unbounded_String ("123456789");
      Opt.Symbol_Prefix := To_Unbounded_String ("CRC");

      while I <= Argument_Count loop
         declare
            Arg  : constant String := Argument (I);
            Name : constant String := Long_Name (Arg);
         begin
            if Name = "--help" or else Arg = "-h" then
               Print_Help;
               Opt.Stop := True;
               return Opt;
            elsif Name = "--version" then
               Ada.Text_IO.Put_Line (Version_String);
               Opt.Stop := True;
               return Opt;
            elsif Name = "--verbose" or else Arg = "-v" then
               Opt.Verbose := True;
            elsif Name = "--force-poly" then
               Opt.Force_Poly := True;
            elsif Name = "--check-string" then
               Opt.Action := Check_String;
               Opt.Check_String := To_Unbounded_String (Take_Value (Arg));
               Note_Action;
            elsif Name = "--check-hexstring" then
               Opt.Action := Check_Hexstring;
               Opt.Check_String := To_Unbounded_String (Take_Value (Arg));
               Note_Action;
            elsif Name = "--check-file" then
               Opt.Action := Check_File;
               Opt.Check_File := To_Unbounded_String (Take_Value (Arg));
               Note_Action;
            elsif Name = "--generate" then
               declare
                  use Ada.Characters.Handling;
                  Kind : constant String := To_Lower (Take_Value (Arg));
               begin
                  if Kind in "ads" | "spec" | "h" then
                     Opt.Generate := Spec;
                  elsif Kind in "adb" | "body" | "c" then
                     Opt.Generate := Body_Part;
                  elsif Kind in "main" | "adb-main" | "c-main" then
                     Opt.Generate := Driver;
                  elsif Kind = "table" then
                     Opt.Generate := Table;
                  else
                     Die ("don't know how to generate " & Kind);
                  end if;
                  Opt.Action := Generate;
                  Note_Action;
               end;
            elsif Name = "--algorithm" then
               Algorithm_Text := To_Unbounded_String (Take_Value (Arg));
            elsif Name = "--model" then
               declare
                  Model_Name : constant String := Take_Value (Arg);
                  Item  : Models.Model;
                  Found : Boolean;
               begin
                  Models.Lookup (Model_Name, Item, Found);
                  if not Found then
                     Die ("unsupported model " & Model_Name
                          & ". Supported models are: " & Models.Names & ".");
                  end if;
                  Opt.Has_Width := True;
                  Opt.Width := Item.Width;
                  Opt.Has_Poly := True;
                  Poly_Raw := (Lo => Item.Poly, Hi => 0);
                  Opt.Has_Reflect_In := True;
                  Opt.Reflect_In := Item.Reflect_In;
                  Opt.Has_Xor_In := True;
                  Xor_In_Raw := (Lo => Item.Xor_In, Hi => 0);
                  Opt.Has_Reflect_Out := True;
                  Opt.Reflect_Out := Item.Reflect_Out;
                  Opt.Has_Xor_Out := True;
                  Xor_Out_Raw := (Lo => Item.Xor_Out, Hi => 0);
               end;
            elsif Name = "--width" then
               declare
                  Text  : constant String := Take_Value (Arg);
                  Value : constant U128 := Parse_U128 ("--width", Text);
               begin
                  Opt.Has_Width := True;
                  if Value.Hi /= 0 or else Value.Lo > Unsigned_64 (Natural'Last)
                  then
                     Die ("widths above 64 are not supported by the Ada port");
                  end if;
                  Opt.Width := Natural (Value.Lo);
               end;
            elsif Name = "--poly" then
               Opt.Has_Poly := True;
               Poly_Raw := Parse_U128 ("--poly", Take_Value (Arg));
            elsif Name = "--reflect-in" then
               Opt.Has_Reflect_In := True;
               Opt.Reflect_In := Parse_Bool ("--reflect-in", Take_Value (Arg));
            elsif Name = "--xor-in" then
               Opt.Has_Xor_In := True;
               Xor_In_Raw := Parse_U128 ("--xor-in", Take_Value (Arg));
            elsif Name = "--reflect-out" then
               Opt.Has_Reflect_Out := True;
               Opt.Reflect_Out :=
                 Parse_Bool ("--reflect-out", Take_Value (Arg));
            elsif Name = "--xor-out" then
               Opt.Has_Xor_Out := True;
               Xor_Out_Raw := Parse_U128 ("--xor-out", Take_Value (Arg));
            elsif Name = "--table-idx-width" then
               declare
                  Text  : constant String := Take_Value (Arg);
                  Value : constant U128 :=
                    Parse_U128 ("--table-idx-width", Text);
               begin
                  if Value.Hi /= 0
                    or else Value.Lo not in 1 | 2 | 4 | 8
                  then
                     Die ("unsupported table-idx-width " & Text);
                  end if;
                  Opt.Table_Idx_Width := Positive (Value.Lo);
               end;
            elsif Name = "--slice-by" then
               declare
                  Text  : constant String := Take_Value (Arg);
                  Value : constant U128 := Parse_U128 ("--slice-by", Text);
               begin
                  if Value.Hi /= 0 or else Value.Lo not in 4 | 8 | 16 then
                     Die ("unsupported slice-by " & Text);
                  end if;
                  Saw_Slice := True;
               end;
            elsif Name = "--symbol-prefix" then
               Opt.Symbol_Prefix := To_Unbounded_String (Take_Value (Arg));
            elsif Name = "--crc-type" then
               declare
                  Ignored : constant String := Take_Value (Arg);
               begin
                  Warn ("--crc-type is ignored; generated CRCs use a modular type");
                  pragma Unreferenced (Ignored);
               end;
            elsif Name = "--std" then
               declare
                  use Ada.Characters.Handling;
                  Text : constant String := To_Upper (Take_Value (Arg));
               begin
                  if Text not in "C89" | "ANSI" | "C99" then
                     Die ("unknown C standard " & Text);
                  end if;
                  Warn ("--std is ignored; the Ada port generates Ada");
               end;
            elsif Name = "--include-file" then
               if Opt.Include_Count = Max_Includes then
                  Die ("too many --include-file options");
               end if;
               Opt.Include_Count := Opt.Include_Count + 1;
               Opt.Includes (Opt.Include_Count) :=
                 To_Unbounded_String (Take_Value (Arg));
            elsif Arg = "-o"
              or else (Starts_With (Arg, "-o") and then not Starts_With (Arg, "--"))
            then
               if Arg = "-o" then
                  Opt.Output_File := To_Unbounded_String (Take_Value (Arg));
               elsif Arg'Length > 2 and then Arg (Arg'First + 2) = '=' then
                  Opt.Output_File :=
                    To_Unbounded_String (Arg (Arg'First + 3 .. Arg'Last));
               else
                  Opt.Output_File :=
                    To_Unbounded_String (Arg (Arg'First + 2 .. Arg'Last));
               end if;
            elsif Name = "--output" then
               Opt.Output_File := To_Unbounded_String (Take_Value (Arg));
            elsif Starts_With (Arg, "-") then
               Die ("unrecognized option: " & Arg);
            else
               if Length (Extra) > 0 then
                  Append (Extra, " ");
               end if;
               Append (Extra, Arg);
            end if;
         end;
         I := I + 1;
      end loop;

      if Length (Extra) > 0 then
         Die ("unrecognized argument(s): " & To_String (Extra));
      end if;

      if Opt.Has_Poly and then not Opt.Force_Poly and then (Poly_Raw.Lo and 1) = 0
      then
         Die ("even polynomials are not allowed by default. "
              & "Use --force-poly to override this.");
      end if;

      if Opt.Has_Width then
         if Opt.Width = 0 then
            Die ("Width must be strictly positive");
         elsif Opt.Width > 64 then
            Die ("widths above 64 are not supported by the Ada port");
         end if;
         if Opt.Has_Poly
           and then not Opt.Force_Poly
           and then Too_Wide (Poly_Raw, Width_Type (Opt.Width))
         then
            Die ("the polynomial is wider than the supplied width. "
                 & "Use --force-poly to override this.");
         end if;
         declare
            Mask : constant Unsigned_64 := Bits_Mask (Width_Type (Opt.Width));
         begin
            if Opt.Has_Poly then
               Opt.Poly := Poly_Raw.Lo and Mask;
            end if;
            if Opt.Has_Xor_In then
               Opt.Xor_In := Xor_In_Raw.Lo and Mask;
            end if;
            if Opt.Has_Xor_Out then
               Opt.Xor_Out := Xor_Out_Raw.Lo and Mask;
            end if;
         end;
      end if;

      if Saw_Slice then
         Warn ("--slice-by is not implemented in the Ada port; "
               & "using a byte-wise table");
      end if;

      declare
         use Ada.Characters.Handling;
         Name : constant String := To_Lower (To_String (Algorithm_Text));
         Any  : Boolean := False;
      begin
         Opt.Algorithm := (False, False, False);
         if Name in "bit-by-bit" | "bbb" | "all" then
            Opt.Algorithm.Bit_By_Bit := True;
            Any := True;
         end if;
         if Name in "bit-by-bit-fast" | "bbf" | "all" then
            Opt.Algorithm.Bit_By_Bit_Fast := True;
            Any := True;
         end if;
         if Name in "table-driven" | "tbl" | "all" then
            Opt.Algorithm.Table_Driven := True;
            Any := True;
         end if;
         if not Any then
            Die ("unknown algorithm " & To_String (Algorithm_Text));
         end if;
      end;

      if Opt.Action /= Generate and then Opt.Table_Idx_Width /= 8 then
         Warn ("reverting to Table Index Width = 8 "
               & "for internal CRC calculation");
         Opt.Table_Idx_Width := 8;
      end if;

      if Opt.Action = Generate and then Opt.Generate = Table then
         if not Opt.Algorithm.Table_Driven then
            Die ("the --generate table option is incompatible "
                 & "with the --algorithm option");
         end if;
         Opt.Algorithm := (False, False, True);
      elsif Opt.Action = Generate then
         if not Exactly_One (Opt.Algorithm) then
            Die ("select an algorithm to be used in the generated file. "
                 & "(Hint: use the --algorithm option.)");
         end if;
      end if;

      if Action_Count > 1 then
         Die ("too many actions specified");
      end if;

      if not (Opt.Has_Width
              and then Opt.Has_Poly
              and then Opt.Has_Reflect_In
              and then Opt.Has_Xor_In
              and then Opt.Has_Reflect_Out
              and then Opt.Has_Xor_Out)
      then
         declare
            Missing : Unbounded_String;
            procedure Add (Flag : String; Present : Boolean) is
            begin
               if not Present then
                  if Length (Missing) > 0 then
                     Append (Missing, ", ");
                  end if;
                  Append (Missing, Flag);
               end if;
            end Add;
         begin
            Add ("--width", Opt.Has_Width);
            Add ("--poly", Opt.Has_Poly);
            Add ("--reflect-in", Opt.Has_Reflect_In);
            Add ("--xor-in", Opt.Has_Xor_In);
            Add ("--reflect-out", Opt.Has_Reflect_Out);
            Add ("--xor-out", Opt.Has_Xor_Out);
            Die ("undefined parameters: Add " & To_String (Missing)
                 & " or use --model");
         end;
      end if;

      return Opt;
   end Parse;

   function Parameter_Block (Opt : Settings) return String is
      function Line (Name, Value : String) return String is
         Pad_Len : constant Natural :=
           (if Name'Length >= 13 then 0 else 13 - Name'Length);
         Pad     : constant String (1 .. Pad_Len) := [others => ' '];
      begin
         return "- " & Name & Pad & " = " & Value;
      end Line;

      function Bool_Image (Value : Boolean) return String is
        (if Value then "True" else "False");

      W : constant Width_Type := Width_Type (Opt.Width);
   begin
      return
        Line ("Width", Decimal_Image (Opt.Width))
        & ASCII.LF
        & Line ("Poly", Hex_Image (Opt.Poly, W))
        & ASCII.LF
        & Line ("XorIn", Hex_Image (Opt.Xor_In, W))
        & ASCII.LF
        & Line ("ReflectIn", Bool_Image (Opt.Reflect_In))
        & ASCII.LF
        & Line ("XorOut", Hex_Image (Opt.Xor_Out, W))
        & ASCII.LF
        & Line ("ReflectOut", Bool_Image (Opt.Reflect_Out));
   end Parameter_Block;

end PyCRC.Options;
