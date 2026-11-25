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

with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Characters.Handling;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Interfaces;
with PyCRC.Algorithms;

package body PyCRC.Codegen is

   use Ada.Strings.Unbounded;
   use Interfaces;

   type Doc is record
      Text : Unbounded_String;
   end record;

   procedure L (D : in out Doc; Indent : Natural; Line : String) is
   begin
      if Indent > 0 then
         Append (D.Text, [1 .. Indent => ' ']);
      end if;
      Append (D.Text, Line);
      Append (D.Text, ASCII.LF);
   end L;

   function Decimal (Value : Natural) return String is
      Text : constant String := Value'Image;
   begin
      return Text (Text'First + 1 .. Text'Last);
   end Decimal;

   function Ada_Hex (Value : Unsigned_64; Bits : Natural) return String is
      Nibble_Count : constant Positive := Positive'Max (1, (Bits + 3) / 4);
      Hexits : constant String := "0123456789ABCDEF";
      Buffer : String (1 .. Nibble_Count) := [others => '0'];
      Rest   : Unsigned_64 := Value;
   begin
      for I in reverse Buffer'Range loop
         Buffer (I) := Hexits (Natural (Rest and 16#F#) + 1);
         Rest := Shift_Right (Rest, 4);
      end loop;
      return "16#" & Buffer & "#";
   end Ada_Hex;

   function Is_Letter (C : Character) return Boolean is
     (C in 'A' .. 'Z' or else C in 'a' .. 'z');

   function Is_Keyword (Name : String) return Boolean is
      use Ada.Characters.Handling;
      N : constant String := To_Lower (Name);
   begin
      return N in "abort" | "abs" | "abstract" | "accept" | "access"
        | "aliased" | "all" | "and" | "array" | "at" | "begin" | "body"
        | "case" | "constant" | "declare" | "delay" | "delta" | "digits"
        | "do" | "else" | "elsif" | "end" | "entry" | "exception" | "exit"
        | "for" | "function" | "generic" | "goto" | "if" | "in"
        | "interface" | "is" | "limited" | "loop" | "mod" | "new" | "not"
        | "null" | "of" | "or" | "others" | "out" | "overriding" | "package"
        | "parallel" | "pragma" | "private" | "procedure" | "protected"
        | "raise" | "range" | "record" | "rem" | "renames" | "requeue"
        | "return" | "reverse" | "select" | "separate" | "some" | "subtype"
        | "synchronized" | "tagged" | "task" | "terminate" | "then" | "type"
        | "until" | "use" | "when" | "while" | "with" | "xor";
   end Is_Keyword;

   function Is_Identifier (Name : String) return Boolean is
      Prev_Underscore : Boolean := False;
   begin
      if Name'Length = 0 or else not Is_Letter (Name (Name'First)) then
         return False;
      end if;
      if Name (Name'Last) = '_' or else Is_Keyword (Name) then
         return False;
      end if;
      for C of Name loop
         if C = '_' then
            if Prev_Underscore then
               return False;
            end if;
            Prev_Underscore := True;
         elsif Is_Letter (C) or else C in '0' .. '9' then
            Prev_Underscore := False;
         else
            return False;
         end if;
      end loop;
      return True;
   end Is_Identifier;

   function Sanitize (Raw : String) return String is
      use Ada.Characters.Handling;
      Result          : Unbounded_String;
      Prev_Underscore : Boolean := True;
   begin
      for C of Raw loop
         if Is_Alphanumeric (C) then
            Append (Result, C);
            Prev_Underscore := False;
         elsif not Prev_Underscore then
            Append (Result, '_');
            Prev_Underscore := True;
         end if;
      end loop;
      if Length (Result) > 0
        and then Element (Result, Length (Result)) = '_'
      then
         Delete (Result, Length (Result), Length (Result));
      end if;
      if Length (Result) = 0 then
         return "CRC";
      end if;
      if Element (Result, 1) in '0' .. '9' then
         return "P_" & To_String (Result);
      end if;
      return To_String (Result);
   end Sanitize;

   function Package_Name (Opt : Options.Settings) return String is
      Raw : constant String := To_String (Opt.Symbol_Prefix);
   begin
      if Is_Identifier (Raw) then
         return Raw;
      end if;
      declare
         Clean : constant String := Sanitize (Raw);
      begin
         if Is_Identifier (Clean) then
            Warn ("symbol prefix """ & Raw
                  & """ is not an Ada identifier; using " & Clean);
            return Clean;
         end if;
         Die ("symbol prefix """ & Raw & """ is not a valid Ada identifier");
      end;
   end Package_Name;

   function Unit_File (Name : String) return String is
      use Ada.Characters.Handling;
      Result : String := To_Lower (Name);
   begin
      for C of Result loop
         if C = '.' then
            C := '-';
         end if;
      end loop;
      return Result;
   end Unit_File;

   function Algorithm_Name (Opt : Options.Settings) return String is
   begin
      if Opt.Algorithm.Bit_By_Bit then
         return "bit-by-bit";
      elsif Opt.Algorithm.Bit_By_Bit_Fast then
         return "bit-by-bit-fast";
      else
         return "table-driven";
      end if;
   end Algorithm_Name;

   function Timestamp return String is
     (Ada.Calendar.Formatting.Image (Ada.Calendar.Clock));

   procedure Add_Banner
     (D : in out Doc; Opt : Options.Settings; Unit_Note : String)
   is
   begin
      L (D, 0, "--  Cyclic redundancy check.");
      L (D, 0, "--");
      L (D, 0, "--  " & Unit_Note);
      L (D, 0, "--  Generated on " & Timestamp);
      L (D, 0, "--  by " & Version_String & ", " & URL);
      L (D, 0, "--  using the configuration:");
      L (D, 0, "--");
      declare
         Block : constant String := Options.Parameter_Block (Opt);
         Start : Positive := Block'First;
      begin
         for I in Block'Range loop
            if Block (I) = ASCII.LF then
               L (D, 0, "--  " & Block (Start .. I - 1));
               Start := I + 1;
            end if;
         end loop;
         if Start <= Block'Last then
            L (D, 0, "--  " & Block (Start .. Block'Last));
         end if;
      end;
      L (D, 0, "--  - Algorithm    = " & Algorithm_Name (Opt));
      if Opt.Algorithm.Table_Driven then
         L (D, 0, "--  - Table_Idx    = " & Decimal (Opt.Table_Idx_Width));
      end if;
      L (D, 0, "--");
      L (D, 0, "--  No copyright is claimed on this generated source.");
   end Add_Banner;

   function Is_Unit_Name (Text : String) return Boolean is
      Start : Positive := Text'First;
   begin
      if Text'Length = 0 then
         return False;
      end if;
      for I in Text'Range loop
         if Text (I) = '.' then
            if not Is_Identifier (Text (Start .. I - 1)) then
               return False;
            end if;
            Start := I + 1;
         end if;
      end loop;
      return Start <= Text'Last and then Is_Identifier (Text (Start .. Text'Last));
   end Is_Unit_Name;

   procedure Add_Spec (D : in out Doc; Opt : Options.Settings; Pack : String) is
      W : constant Width_Type := Width_Type (Opt.Width);
   begin
      Add_Banner (D, Opt,
                  "Package specification. GNAT file name: " & Unit_File (Pack) & ".ads");
      L (D, 0, "--");
      L (D, 0, "--  Call Init, then Update any number of times, then Finalize.");
      L (D, 0, "--  Calculate combines the three calls.");
      L (D, 0, "");
      L (D, 0, "with Interfaces;");
      for I in 1 .. Opt.Include_Count loop
         declare
            Unit : constant String := To_String (Opt.Includes (I));
         begin
            if not Is_Unit_Name (Unit) then
               Warn ("ignoring --include-file " & Unit
                     & " (not an Ada unit name)");
            elsif Ada.Characters.Handling.To_Lower (Unit) /= "interfaces" then
               L (D, 0, "with " & Unit & ";");
            end if;
         end;
      end loop;
      L (D, 0, "");
      L (D, 0, "package " & Pack & " is");
      L (D, 0, "");
      L (D, 3, "subtype Byte is Interfaces.Unsigned_8;");
      L (D, 3, "type Byte_Array is array (Positive range <>) of Byte;");
      L (D, 0, "");
      L (D, 3, "Width : constant := " & Decimal (Opt.Width) & ";");
      L (D, 0, "");
      L (D, 3, "type CRC_Type is mod 2 ** Width;");
      L (D, 0, "");
      L (D, 3, "Poly        : constant CRC_Type := "
         & Ada_Hex (Opt.Poly, W) & ";");
      L (D, 3, "Xor_In      : constant CRC_Type := "
         & Ada_Hex (Opt.Xor_In, W) & ";");
      L (D, 3, "Xor_Out     : constant CRC_Type := "
         & Ada_Hex (Opt.Xor_Out, W) & ";");
      L (D, 3, "Reflect_In  : constant Boolean := "
         & (if Opt.Reflect_In then "True" else "False") & ";");
      L (D, 3, "Reflect_Out : constant Boolean := "
         & (if Opt.Reflect_Out then "True" else "False") & ";");
      L (D, 0, "");
      L (D, 3, "function Init return CRC_Type;");
      L (D, 0, "");
      L (D, 3, "function Update");
      L (D, 6, "(CRC : CRC_Type; Data : Byte_Array) return CRC_Type;");
      L (D, 0, "");
      L (D, 3, "function Finalize (CRC : CRC_Type) return CRC_Type;");
      L (D, 0, "");
      L (D, 3, "function Calculate (Data : Byte_Array) return CRC_Type is");
      L (D, 6, "(Finalize (Update (Init, Data)));");
      L (D, 0, "");
      L (D, 0, "end " & Pack & ";");
      L (D, 0, "");
   end Add_Spec;

   procedure Add_Support
     (D            : in out Doc;
      Opt          : Options.Settings;
      Need_Shl     : Boolean;
      Need_Shr     : Boolean;
      Need_Reflect : Boolean)
   is
      W : constant Width_Type := Width_Type (Opt.Width);
      Emit_Shl : constant Boolean := Need_Shl or else Need_Reflect;
      Emit_Shr : constant Boolean := Need_Shr or else Need_Reflect;
   begin
      L (D, 3, "use Interfaces;");
      L (D, 0, "");
      L (D, 3, "Mask : constant Unsigned_64 := " & Ada_Hex (Bits_Mask (W), 64) & ";");
      if Opt.Algorithm.Bit_By_Bit or else Opt.Algorithm.Bit_By_Bit_Fast then
         L (D, 3, "MSB  : constant Unsigned_64 := " & Ada_Hex (MSB_Mask (W), 64) & ";");
         L (D, 3, "Poly_U : constant Unsigned_64 := Unsigned_64 (Poly);");
      end if;
      if Emit_Shl then
         L (D, 0, "");
         L (D, 3, "function Shl (Value : Unsigned_64; Amount : Natural) return Unsigned_64 is");
         L (D, 3, "begin");
         L (D, 6, "if Amount = 0 then");
         L (D, 9, "return Value;");
         L (D, 6, "elsif Amount >= 64 then");
         L (D, 9, "return 0;");
         L (D, 6, "else");
         L (D, 9, "return Shift_Left (Value, Amount);");
         L (D, 6, "end if;");
         L (D, 3, "end Shl;");
      end if;
      if Emit_Shr then
         L (D, 0, "");
         L (D, 3, "function Shr (Value : Unsigned_64; Amount : Natural) return Unsigned_64 is");
         L (D, 3, "begin");
         L (D, 6, "if Amount = 0 then");
         L (D, 9, "return Value;");
         L (D, 6, "elsif Amount >= 64 then");
         L (D, 9, "return 0;");
         L (D, 6, "else");
         L (D, 9, "return Shift_Right (Value, Amount);");
         L (D, 6, "end if;");
         L (D, 3, "end Shr;");
      end if;
      if Need_Reflect then
         L (D, 0, "");
         L (D, 3, "function Reflect");
         L (D, 6, "(Data : Unsigned_64; Bits : Natural) return Unsigned_64");
         L (D, 3, "is");
         L (D, 6, "Result : Unsigned_64 := Data and 1;");
         L (D, 6, "Value  : Unsigned_64 := Data;");
         L (D, 3, "begin");
         L (D, 6, "for Step in 1 .. Bits - 1 loop");
         L (D, 9, "Value := Shr (Value, 1);");
         L (D, 9, "Result := Shl (Result, 1) or (Value and 1);");
         L (D, 6, "end loop;");
         L (D, 6, "return Result;");
         L (D, 3, "end Reflect;");
      end if;
   end Add_Support;

   procedure Add_BBB (D : in out Doc; Opt : Options.Settings) is
   begin
      L (D, 0, "");
      L (D, 3, "function Init return CRC_Type is");
      L (D, 6, "Reg : Unsigned_64 := Unsigned_64 (Xor_In);");
      L (D, 3, "begin");
      L (D, 6, "for Step in 1 .. Width loop");
      L (D, 9, "declare");
      L (D, 12, "Bit : constant Boolean := (Reg and 1) /= 0;");
      L (D, 9, "begin");
      L (D, 12, "if Bit then");
      L (D, 15, "Reg := Reg xor Poly_U;");
      L (D, 12, "end if;");
      L (D, 12, "Reg := Shr (Reg, 1);");
      L (D, 12, "if Bit then");
      L (D, 15, "Reg := Reg or MSB;");
      L (D, 12, "end if;");
      L (D, 9, "end;");
      L (D, 6, "end loop;");
      L (D, 6, "return CRC_Type (Reg and Mask);");
      L (D, 3, "end Init;");
      L (D, 0, "");
      L (D, 3, "function Update");
      L (D, 6, "(CRC : CRC_Type; Data : Byte_Array) return CRC_Type");
      L (D, 3, "is");
      L (D, 6, "Reg : Unsigned_64 := Unsigned_64 (CRC);");
      L (D, 3, "begin");
      L (D, 6, "for Octet of Data loop");
      L (D, 9, "declare");
      if Opt.Reflect_In then
         L (D, 12, "C : Unsigned_64 := Unsigned_64 (Octet);");
      else
         L (D, 12, "C : constant Unsigned_64 := Unsigned_64 (Octet);");
      end if;
      L (D, 9, "begin");
      if Opt.Reflect_In then
         L (D, 12, "C := Reflect (C, 8);");
      end if;
      L (D, 12, "for I in 0 .. 7 loop");
      L (D, 15, "declare");
      L (D, 18, "Top : constant Boolean := (Reg and MSB) /= 0;");
      L (D, 18, "Bit : constant Unsigned_64 := Shr (C, 7 - I) and 1;");
      L (D, 15, "begin");
      L (D, 18, "Reg := (Shl (Reg, 1) or Bit) and Mask;");
      L (D, 18, "if Top then");
      L (D, 21, "Reg := Reg xor Poly_U;");
      L (D, 18, "end if;");
      L (D, 15, "end;");
      L (D, 12, "end loop;");
      L (D, 9, "end;");
      L (D, 6, "end loop;");
      L (D, 6, "return CRC_Type (Reg and Mask);");
      L (D, 3, "end Update;");
      L (D, 0, "");
      L (D, 3, "function Finalize (CRC : CRC_Type) return CRC_Type is");
      L (D, 6, "Reg : Unsigned_64 := Unsigned_64 (CRC);");
      L (D, 3, "begin");
      L (D, 6, "for Step in 1 .. Width loop");
      L (D, 9, "declare");
      L (D, 12, "Top : constant Boolean := (Reg and MSB) /= 0;");
      L (D, 9, "begin");
      L (D, 12, "Reg := Shl (Reg, 1) and Mask;");
      L (D, 12, "if Top then");
      L (D, 15, "Reg := Reg xor Poly_U;");
      L (D, 12, "end if;");
      L (D, 9, "end;");
      L (D, 6, "end loop;");
      if Opt.Reflect_Out then
         L (D, 6, "Reg := Reflect (Reg, Width);");
      end if;
      L (D, 6, "return CRC_Type ((Reg xor Unsigned_64 (Xor_Out)) and Mask);");
      L (D, 3, "end Finalize;");
   end Add_BBB;

   procedure Add_BBF (D : in out Doc; Opt : Options.Settings) is
   begin
      L (D, 0, "");
      L (D, 3, "function Init return CRC_Type is (Xor_In);");
      L (D, 0, "");
      L (D, 3, "function Update");
      L (D, 6, "(CRC : CRC_Type; Data : Byte_Array) return CRC_Type");
      L (D, 3, "is");
      L (D, 6, "Reg : Unsigned_64 := Unsigned_64 (CRC);");
      L (D, 3, "begin");
      L (D, 6, "for Octet of Data loop");
      L (D, 9, "declare");
      if Opt.Reflect_In then
         L (D, 12, "C : Unsigned_64 := Unsigned_64 (Octet);");
      else
         L (D, 12, "C : constant Unsigned_64 := Unsigned_64 (Octet);");
      end if;
      L (D, 9, "begin");
      if Opt.Reflect_In then
         L (D, 12, "C := Reflect (C, 8);");
      end if;
      L (D, 12, "for I in 0 .. 7 loop");
      L (D, 15, "declare");
      L (D, 18, "Top : Boolean := (Reg and MSB) /= 0;");
      L (D, 15, "begin");
      L (D, 18, "if (C and Shl (1, 7 - I)) /= 0 then");
      L (D, 21, "Top := not Top;");
      L (D, 18, "end if;");
      L (D, 18, "Reg := Shl (Reg, 1) and Mask;");
      L (D, 18, "if Top then");
      L (D, 21, "Reg := Reg xor Poly_U;");
      L (D, 18, "end if;");
      L (D, 15, "end;");
      L (D, 12, "end loop;");
      L (D, 9, "end;");
      L (D, 6, "end loop;");
      L (D, 6, "return CRC_Type (Reg and Mask);");
      L (D, 3, "end Update;");
      L (D, 0, "");
      if Opt.Reflect_Out then
         L (D, 3, "function Finalize (CRC : CRC_Type) return CRC_Type is");
         L (D, 6, "Reg : constant Unsigned_64 := Reflect (Unsigned_64 (CRC), Width);");
         L (D, 3, "begin");
         L (D, 6, "return CRC_Type ((Reg xor Unsigned_64 (Xor_Out)) and Mask);");
         L (D, 3, "end Finalize;");
      else
         L (D, 3, "function Finalize (CRC : CRC_Type) return CRC_Type is");
         L (D, 6, "(CRC_Type ((Unsigned_64 (CRC) xor Unsigned_64 (Xor_Out)) and Mask));");
      end if;
   end Add_BBF;

   procedure Add_Table_Aggregate
     (D : in out Doc; Table : Algorithms.Word_Array; Bits : Natural)
   is
      Per_Line : constant Positive := (if Bits > 32 then 4 else 8);
      Column   : Natural := 0;
      Line     : Unbounded_String;
   begin
      L (D, 3, "Table : constant array (0 .. "
         & Decimal (Table'Length - 1) & ") of CRC_Type :=");
      L (D, 5, "[");
      for I in Table'Range loop
         if Column = 0 then
            Line := To_Unbounded_String ("");
         else
            Append (Line, " ");
         end if;
         Append (Line, Ada_Hex (Table (I), Bits));
         Column := Column + 1;
         if Column = Per_Line or else I = Table'Last then
            if I /= Table'Last then
               Append (Line, ",");
            end if;
            L (D, 6, To_String (Line));
            Column := 0;
         else
            Append (Line, ",");
         end if;
      end loop;
      L (D, 5, "];");
   end Add_Table_Aggregate;

   procedure Add_TBL (D : in out Doc; Opt : Options.Settings) is
      W     : constant Width_Type := Width_Type (Opt.Width);
      Idx_W : constant Algorithms.Table_Index_Width :=
        Algorithms.Table_Index_Width (Opt.Table_Idx_Width);
      Table : constant Algorithms.Word_Array :=
        Algorithms.Lookup_Table (W, Opt.Poly, Opt.Reflect_In, Idx_W);
      Chunks : constant Natural := 8 / Positive (Idx_W);
   begin
      L (D, 0, "");
      if Chunks > 1 or else W > Positive (Idx_W) then
         L (D, 3, "Idx_Width : constant := " & Decimal (Opt.Table_Idx_Width) & ";");
      end if;
      L (D, 3, "Table_Mask : constant Unsigned_64 := "
         & Ada_Hex (Unsigned_64 (2 ** Opt.Table_Idx_Width - 1), 8) & ";");
      L (D, 0, "");
      Add_Table_Aggregate (D, Table, W);
      L (D, 0, "");
      if Opt.Reflect_In then
         L (D, 3, "function Init return CRC_Type is");
         L (D, 6, "(CRC_Type (Reflect (Unsigned_64 (Xor_In), Width) and Mask));");
      else
         L (D, 3, "function Init return CRC_Type is (Xor_In);");
      end if;
      L (D, 0, "");
      L (D, 3, "function Update");
      L (D, 6, "(CRC : CRC_Type; Data : Byte_Array) return CRC_Type");
      L (D, 3, "is");
      L (D, 6, "Reg : Unsigned_64 := Unsigned_64 (CRC);");
      L (D, 3, "begin");
      L (D, 6, "for Octet of Data loop");
      if Chunks > 1 then
         L (D, 9, "for I in 0 .. " & Decimal (Chunks - 1) & " loop");
      end if;
      declare
         Base : constant Natural := (if Chunks = 1 then 9 else 12);
         Step : constant String := (if Chunks = 1 then "0" else "I");
      begin
         L (D, Base, "declare");
         if Opt.Reflect_In then
            if Chunks = 1 then
               L (D, Base + 3, "Idx : constant Natural :=");
               L (D, Base + 6,
                  "Natural ((Reg xor Unsigned_64 (Octet)) and Table_Mask);");
            else
               L (D, Base + 3, "Shifted : constant Unsigned_64 :=");
               L (D, Base + 6, "Shr (Unsigned_64 (Octet), " & Step
                  & " * Idx_Width);");
               L (D, Base + 3, "Idx : constant Natural :=");
               L (D, Base + 6,
                  "Natural ((Reg xor Shifted) and Table_Mask);");
            end if;
         else
            if Chunks = 1 then
               null;
            else
               L (D, Base + 3, "Byte_Shift : constant Natural :=");
               L (D, Base + 6, "8 - (" & Step & " + 1) * Idx_Width;");
               L (D, Base + 3, "Shifted : constant Unsigned_64 :=");
               L (D, Base + 6, "Shr (Unsigned_64 (Octet), Byte_Shift);");
            end if;
            if W < Positive (Idx_W) then
               L (D, Base + 3, "CRC_Shifted : constant Unsigned_64 :=");
               L (D, Base + 6, "Shl (Reg, "
                  & Decimal (Positive (Idx_W) - Positive (W)) & ");");
            else
               L (D, Base + 3, "CRC_Shifted : constant Unsigned_64 :=");
               L (D, Base + 6, "Shr (Reg, "
                  & Decimal (Positive (W) - Positive (Idx_W)) & ");");
            end if;
            if Chunks = 1 then
               L (D, Base + 3, "Idx : constant Natural :=");
               L (D, Base + 6,
                  "Natural ((CRC_Shifted xor Unsigned_64 (Octet)) and Table_Mask);");
            else
               L (D, Base + 3, "Idx : constant Natural :=");
               L (D, Base + 6,
                  "Natural ((CRC_Shifted xor Shifted) and Table_Mask);");
            end if;
         end if;
         L (D, Base, "begin");
         if W <= Positive (Idx_W) then
            L (D, Base + 3, "Reg := Unsigned_64 (Table (Idx)) and Mask;");
         elsif Opt.Reflect_In then
            L (D, Base + 3,
               "Reg := (Unsigned_64 (Table (Idx)) xor Shr (Reg, Idx_Width)) and Mask;");
         else
            L (D, Base + 3,
               "Reg := (Unsigned_64 (Table (Idx)) xor Shl (Reg, Idx_Width)) and Mask;");
         end if;
         L (D, Base, "end;");
      end;
      if Chunks > 1 then
         L (D, 9, "end loop;");
      end if;
      L (D, 6, "end loop;");
      L (D, 6, "return CRC_Type (Reg and Mask);");
      L (D, 3, "end Update;");
      L (D, 0, "");
      L (D, 3, "function Finalize (CRC : CRC_Type) return CRC_Type is");
      if Opt.Reflect_In = Opt.Reflect_Out then
         L (D, 6, "(CRC_Type ((Unsigned_64 (CRC) xor Unsigned_64 (Xor_Out)) and Mask));");
      else
         L (D, 6, "Reg : constant Unsigned_64 :=");
         L (D, 9, "Reflect (Unsigned_64 (CRC), Width);");
         L (D, 3, "begin");
         L (D, 6, "return CRC_Type ((Reg xor Unsigned_64 (Xor_Out)) and Mask);");
         L (D, 3, "end Finalize;");
      end if;
   end Add_TBL;

   procedure Add_Body (D : in out Doc; Opt : Options.Settings; Pack : String) is
      Need_Reflect : constant Boolean := Opt.Reflect_In or else Opt.Reflect_Out;
      Need_Shr     : constant Boolean :=
        Opt.Algorithm.Bit_By_Bit or else Opt.Algorithm.Table_Driven;
      Need_Shl     : constant Boolean :=
        Opt.Algorithm.Bit_By_Bit
        or else Opt.Algorithm.Bit_By_Bit_Fast
        or else (Opt.Algorithm.Table_Driven
                 and then not Opt.Reflect_In
                 and then Opt.Width /= Opt.Table_Idx_Width);
   begin
      Add_Banner (D, Opt,
                  "Package body. GNAT file name: " & Unit_File (Pack) & ".adb");
      L (D, 0, "");
      L (D, 0, "package body " & Pack & " is");
      L (D, 0, "");
      Add_Support (D, Opt, Need_Shl, Need_Shr, Need_Reflect);
      if Opt.Algorithm.Bit_By_Bit then
         Add_BBB (D, Opt);
      elsif Opt.Algorithm.Bit_By_Bit_Fast then
         Add_BBF (D, Opt);
      else
         Add_TBL (D, Opt);
      end if;
      L (D, 0, "");
      L (D, 0, "end " & Pack & ";");
      L (D, 0, "");
   end Add_Body;

   procedure Add_Driver (D : in out Doc; Pack : String) is
      Proc : constant String := Pack & "_Main";
   begin
      L (D, 0, "--  Driver for the generated " & Pack & " package.");
      L (D, 0, "--  GNAT file name: " & Unit_File (Proc) & ".adb");
      L (D, 0, "--  With no arguments, checksums the ASCII string ""123456789"".");
      L (D, 0, "--  One argument replaces that string. The result is printed as 0x....");
      L (D, 0, "");
      L (D, 0, "with Ada.Command_Line;");
      L (D, 0, "with Ada.Text_IO;");
      L (D, 0, "with Interfaces;");
      L (D, 0, "with " & Pack & ";");
      L (D, 0, "");
      L (D, 0, "procedure " & Proc & " is");
      L (D, 0, "");
      L (D, 3, "function To_Bytes (Text : String) return " & Pack & ".Byte_Array is");
      L (D, 6, "Result : " & Pack & ".Byte_Array (1 .. Text'Length);");
      L (D, 3, "begin");
      L (D, 6, "for I in Text'Range loop");
      L (D, 9, "Result (Result'First + (I - Text'First)) :=");
      L (D, 12, Pack & ".Byte (Character'Pos (Text (I)));");
      L (D, 6, "end loop;");
      L (D, 6, "return Result;");
      L (D, 3, "end To_Bytes;");
      L (D, 0, "");
      L (D, 3, "function Hex (Value : " & Pack & ".CRC_Type) return String is");
      L (D, 6, "use Interfaces;");
      L (D, 6, "Hexits : constant String := ""0123456789abcdef"";");
      L (D, 6, "Buffer : String (1 .. 16) := [others => '0'];");
      L (D, 6, "Rest   : Unsigned_64 := Unsigned_64 (Value);");
      L (D, 6, "Pos    : Natural := Buffer'Last;");
      L (D, 3, "begin");
      L (D, 6, "if Rest = 0 then");
      L (D, 9, "return ""0x0"";");
      L (D, 6, "end if;");
      L (D, 6, "while Rest /= 0 loop");
      L (D, 9, "Buffer (Pos) := Hexits (Natural (Rest and 16#F#) + 1);");
      L (D, 9, "Rest := Shift_Right (Rest, 4);");
      L (D, 9, "Pos := Pos - 1;");
      L (D, 6, "end loop;");
      L (D, 6, "return ""0x"" & Buffer (Pos + 1 .. Buffer'Last);");
      L (D, 3, "end Hex;");
      L (D, 0, "");
      L (D, 3, "Text : constant String :=");
      L (D, 6, "(if Ada.Command_Line.Argument_Count > 0");
      L (D, 9, "then Ada.Command_Line.Argument (1)");
      L (D, 9, "else ""123456789"");");
      L (D, 0, "begin");
      L (D, 3, "Ada.Text_IO.Put_Line (Hex (" & Pack & ".Calculate (To_Bytes (Text))));");
      L (D, 0, "end " & Proc & ";");
      L (D, 0, "");
   end Add_Driver;

   procedure Add_Table_Only (D : in out Doc; Opt : Options.Settings) is
      W     : constant Width_Type := Width_Type (Opt.Width);
      Idx_W : constant Algorithms.Table_Index_Width :=
        Algorithms.Table_Index_Width (Opt.Table_Idx_Width);
      Table : constant Algorithms.Word_Array :=
        Algorithms.Lookup_Table (W, Opt.Poly, Opt.Reflect_In, Idx_W);
   begin
      Add_Banner (D, Opt, "CRC lookup table.");
      L (D, 0, "");
      Add_Table_Aggregate (D, Table, W);
      L (D, 0, "");
   end Add_Table_Only;

   procedure Write_Output (Opt : Options.Settings; Text : String) is
      use Ada.Text_IO;
      Name : constant String := To_String (Opt.Output_File);
   begin
      if Name'Length = 0 then
         Put (Text);
      else
         declare
            File : File_Type;
         begin
            Create (File, Out_File, Name);
            Put (File, Text);
            Close (File);
         exception
            when Name_Error | Use_Error | Status_Error | Device_Error =>
               Die ("cannot write to file " & Name);
         end;
      end if;
   end Write_Output;

   procedure Generate (Opt : Options.Settings) is
      D    : Doc;
      Pack : constant String := Package_Name (Opt);
   begin
      case Opt.Generate is
         when Options.Spec =>
            Add_Spec (D, Opt, Pack);
         when Options.Body_Part =>
            Add_Body (D, Opt, Pack);
         when Options.Driver =>
            Add_Driver (D, Pack);
         when Options.Table =>
            Add_Table_Only (D, Opt);
      end case;
      Write_Output (Opt, To_String (D.Text));
   end Generate;

end PyCRC.Codegen;
