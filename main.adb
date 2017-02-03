with Ada.Command_Line; use Ada.Command_Line;
with Ada.Text_IO; use Ada.Text_IO;
with Ada.Real_Time;
with Ada.Unchecked_Conversion;

procedure Main is
	pragma Suppress(All_Checks);

	Matrix_Size : constant := 3200;
	type Matrix_Range is range 0 .. Matrix_Size - 1;
	Bound_High, Bound_Low : Matrix_Range;

	type Pile is range 0..7 with Size=>8;
	type Pile_Pointer is access all Pile;

	type Generic_Matrix_Row is array (Matrix_Range range <>) of aliased Pile with Pack;
	subtype Matrix_Row is Generic_Matrix_Row(Matrix_Range);
	subtype Matrix_Sub_Row is Generic_Matrix_Row(0..7);
	type Matrix is array (Matrix_Range) of Matrix_Row with Pack;
	type Matrix_Pointer is access all Matrix;

	type m128i is array (0 .. 15) of Pile with Pack, Alignment=>16;
	pragma Machine_Attribute (m128i, "vector_type");
	pragma Machine_Attribute (m128i, "may_alias");

----------------------------------------------------------------------

	function ia32_Add (X, Y : m128i) return m128i with Inline;
	pragma Import (Intrinsic, ia32_Add, "__builtin_ia32_paddb128");
	function ia32_Load (X : Pile_Pointer) return m128i with Inline;
	pragma Import (Intrinsic, ia32_Load, "__builtin_ia32_loaddqu");
	procedure ia32_Store (X : Pile_Pointer; Y : m128i) with Inline;
	pragma Import (Intrinsic, ia32_Store, "__builtin_ia32_storedqu");

	procedure Print (Map : in Matrix; Name : in String) is
	begin
		Put_Line(Name);
		for I in Bound_Low .. Bound_High loop
			for J in Bound_Low .. Bound_High loop
				Put(Pile'Image(Map(I)(J)));
			end loop;
			New_Line(1);
		end loop;
		Put_Line("------------");
	end;

	function Topple (Base : in Matrix_Pointer) return Boolean is
		type Mod_64 is mod 2**64;
		type Mod_64_Array is array (0..1) of aliased Mod_64;
		type Mod_64_Pointer is access all Mod_64;
		function ia32_Load (X : Mod_64_Pointer) return m128i with Inline;
		pragma Import (Intrinsic, ia32_Load, "__builtin_ia32_loaddqu");
		function Move is new Ada.Unchecked_Conversion (Source=>Mod_64, Target=>Matrix_Sub_Row);
		function Move is new Ada.Unchecked_Conversion (Source=>Matrix_Sub_Row, Target=>Mod_64);

		Changed : Boolean := False;
		Local_Bound_High : constant Matrix_Range := Bound_High;
		Local_Bound_Low : constant Matrix_Range := Bound_Low;
		I : Matrix_Range := Bound_Low;
		Temp_Values : Mod_64_Array;

	begin
		while I <= Local_Bound_High loop
			declare
				J : Matrix_Range := Local_Bound_Low - (Local_Bound_Low mod 16);
				Temp : m128i;
				Sum_m128i_Buffer : m128i;
				Upper_Sum_m128i_Buffer : m128i;
				Lower_Sum_m128i_Buffer : m128i;
			begin
				while J <= Local_Bound_High loop
					Temp_Values(0) := (Move(Base(I)(J..J+7)) / 2**2) AND 16#0F0F0F0F0F0F0F0F#;
					Temp_Values(1) := (Move(Base(I)(J+8..J+15)) / 2**2) AND 16#0F0F0F0F0F0F0F0F#;

					if (Temp_Values(0) OR Temp_Values(1)) /= 0 then
						Changed := True;
						if I - 1 < Bound_Low then
							Bound_Low := Bound_Low - 1;
							Bound_High := Bound_High + 1;
						end if;
						Temp := ia32_Load(Temp_Values(0)'Access);

						Upper_Sum_m128i_Buffer := ia32_Load(Base(I-1)(J)'Access);
						ia32_Store(Base(I-1)(J)'Access, ia32_Add(Upper_Sum_m128i_Buffer, Temp));

						Lower_Sum_m128i_Buffer := ia32_Load(Base(I+1)(J)'Access);
						ia32_Store(Base(I+1)(J)'Access, ia32_Add(Lower_Sum_m128i_Buffer, Temp));

						Sum_m128i_Buffer := ia32_Load(Base(I)(J-1)'Access);
						ia32_Store(Base(I)(J-1)'Access, ia32_Add(Sum_m128i_Buffer, Temp));

						Sum_m128i_Buffer := ia32_Load(Base(I)(J+1)'Access);
						ia32_Store(Base(I)(J+1)'Access, ia32_Add(Sum_m128i_Buffer, Temp));

						Base(I)(J..J+7) := Move(Move(Base(I)(J..J+7)) - (Temp_Values(0) * 4));
						Base(I)(J+8..J+15) := Move(Move(Base(I)(J+8..J+15)) - (Temp_Values(1) * 4));
					end if;

					J := J + 16;
				end loop;
			end;
			I := I + 1;
		end loop;
		return Changed;
	end Topple;

	function Drip (Value : in out Natural) return Pile with Inline is
	begin
		if Value /= 0 then
			Value := Value - 4;
			return 4;
		else
			return 0;
		end if;
	end Drip;

	procedure Color (Item : in Matrix) with Import, Convention=>C, Link_Name=>"color_map";

----------------------------------------------------------------------


	Base_Matrix : constant Matrix_Pointer := new Matrix'(others=>(others=>0));

	Input_Sand_Stream : Natural := Natural'Value(Argument(1));

	Center : constant Matrix_Range := Matrix_Range'Last/2;

begin

	if Input_Sand_Stream mod 4 /= 0 then
		raise Constraint_Error with "Input should be multiple for 4";
	end if;

	if Matrix_Size mod 16 /= 0 then
		raise Constraint_Error with "Compiled with a bad matrix size";
	end if;

	if Natural(Matrix_Size**2 * 1.5) < Input_Sand_Stream then
		raise Constraint_Error with "Optimazation accounting for an infinite plane makes that input dangerous";
	end if;

	Bound_High := Center;
	Bound_Low := Center;

	Base_Matrix(Center)(Center) := Base_Matrix(Center)(Center) + Drip(Input_Sand_Stream);

	declare
		use type Ada.Real_Time.Time;
		Start_Time :constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
		End_Time : Ada.Real_Time.Time;
	begin
		while Topple(Base_Matrix) loop
			if Input_Sand_Stream mod 2048 = 0 then
				Put_Line(Natural'Image(Input_Sand_Stream));
				Put_Line(Matrix_Range'Image(Bound_High));
				Put_Line(Matrix_Range'Image(Bound_Low));
			end if;

			if Base_Matrix(Center)(Center) < 4 then
				Base_Matrix(Center)(Center) := Base_Matrix(Center)(Center) + Drip(Input_Sand_Stream);
			end if;
		end loop;

		End_Time := Ada.Real_Time.Clock;
		Put_Line(Duration'Image(Ada.Real_Time.To_Duration(End_Time-Start_Time)));
		Put_Line("Printing...");
	end;

	Color(Base_Matrix.all);

end Main;