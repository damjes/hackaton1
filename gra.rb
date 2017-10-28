require 'gosu'
require 'json'

module Rozmycie
	def zacznij_rozmycie
		@kat_rozmycia = 0
	end

	def klatka_rozmycia
		@kat_rozmycia += 0.005
		if @kat_rozmycia > 2 * Math::PI
			@kat_rozmycia -= 2 * Math::PI
		end
	end

	def rysuj_rozmyte obrazek, x, y, scale_x = 1, scale_y = 1
		zmiana_x_1 = @gracz.upojenie * 3 * Math.sin(3 * @kat_rozmycia)
		zmiana_y_1 = @gracz.upojenie * 3 * Math.sin(4 * @kat_rozmycia)

		zmiana_x_2 = @gracz.upojenie * 3 * Math.sin(5 * @kat_rozmycia)
		zmiana_y_2 = @gracz.upojenie * 3 * Math.sin(7 * @kat_rozmycia)

		obrazek.draw x, y, 0, scale_x, scale_y
		obrazek.draw x+zmiana_x_1.to_i, y+zmiana_y_1.to_i, 1, scale_x, scale_y, Gosu::Color.argb(0x80_ffffff)
		obrazek.draw x+zmiana_x_2.to_i, y+zmiana_y_2.to_i, 1, scale_x, scale_y, Gosu::Color.argb(0x40_ffffff)
	end
end

class Gienaddij
	include Rozmycie

	attr_reader :upojenie

	def initialize gra
		@gra = gra
		@upojenie = 100
		@etanol = 0
		@fiolet = 0
		@grafika = Gosu::Image.load_tiles 'grafiki/rusek.png', 64, 64
		@do_zmiany_klatki = 15
		@klatka = 0
		@sprajt = 0
		@kierunek = 1
		@gracz = self #żeby działało rozmycie
		zacznij_rozmycie
	end

	def ustaw x, y
		@x = x
		@y = y
		@xprim = 0
		@yprim = 0
	end

	def przesun delta
		@xprim += delta
		if @xprim > 32
			@xprim = -32 + delta
			@x += 1
		elsif @xprim < -31
			@xprim = 32 - delta
			@x -= 1
		end

		@do_zmiany_klatki -= 1
		if @do_zmiany_klatki < 0
			@klatka += 1
			@klatka = 0 if @klatka > 3
			@do_zmiany_klatki = 15
		end
		@sprajt = @klatka + 24

		@kierunek = if delta > 0
			1
		else
			-1
		end
	end

	def cios
		if @upojenie > 0
			@upojenie -= 1
		else
			@gra.przegral = true
		end
	end

	def narysuj
		rysuj_rozmyte @grafika[@sprajt], @x*64+@xprim+32*(1-@kierunek), @y*64+@yprim, @kierunek
	end

	def probuj_przesunac
		przesun -2 if Gosu.button_down? Gosu::KbLeft
		przesun  2 if Gosu.button_down? Gosu::KbRight
	end

	def update
		klatka_rozmycia
		@do_zmiany_klatki -= 1
		if @do_zmiany_klatki < 0
			@klatka += 1
			@klatka = 0 if @klatka > 3
			@do_zmiany_klatki = 15
		end
		@sprajt = @klatka
		probuj_przesunac
	end
end

class Okno < Gosu::Window
	include Rozmycie

	def initialize
		super 1920, 1080, true
		#super 800, 600, false
		@caption = "Gienaddij Destilowicz"
		zacznij_rozmycie
		@grafiki = Gosu::Image.load_tiles 'grafiki/pola.png', 64, 64
		@gracz = Gienaddij.new self
		wczytaj_plansze 'plansza.ppm'
		show
	end

	def czytaj_kolor strumien
		r = strumien.getbyte
		g = strumien.getbyte
		b = strumien.getbyte

		case 256*(256*r+g)+b
		when 0x000000 then :niebo
		when 0xC00000 then :drewno
		when 0xFF0000 then :metal
		when 0x800000 then :skrzynka
		when 0x400000 then :ziemia
		when 0x000040 then :gracz
		when 0x000080 then :zielony_ludzik
		when 0x0000C0 then :elf
		when 0x0000FF then :krasnal
		when 0x00FF00 then :denaturat
		when 0x00C000 then :wódka
		else raise 'Nieznany kolor'
		end
	end

	def przetworz_kolor strumien, x, y
		kolor = czytaj_kolor strumien
		if kolor == :gracz
			@gracz.ustaw x, y
			return :niebo
		else
			return kolor
		end
	end

	def czytaj_macierz strumien, x, y
		@plansza = []
		y.times do |nr_wiersza|
			wiersz = []
			x.times do |nr_kolumny|
				symbol = przetworz_kolor strumien, nr_kolumny, nr_wiersza
				wiersz << symbol
			end
			@plansza << wiersz
		end
	end

	def wczytaj_plansze plik
		File.open(plik, 'r') do |uchwyt|
			raise 'Wymagany tryb P6' unless uchwyt.gets.chomp == 'P6'
			linia = uchwyt.gets
			while linia.chr == '#'
				linia = uchwyt.gets
			end
			@wymiary = linia.split
			raise 'Wymagana paleta 255 wartości na kanał' unless uchwyt.gets.chomp == '255'
			czytaj_macierz uchwyt, @wymiary[0].to_i, @wymiary[1].to_i
		end
	end

	def draw
		rysuj_pola
		@gracz.narysuj
	end

	def rysuj_pola
		@plansza.each_with_index do |wiersz, y|
			wiersz.each_with_index do |komorka, x|
				numer = case @plansza[y][x]
				when :metal then 1
				when :skrzynka then 2
				when :drewno then 3
				when :ziemia then 4
				when :pnacze then 5
				else 0
				end

				rysuj_rozmyte @grafiki[numer], x*64, y*64
			end
		end
	end

	def update
		klatka_rozmycia
		close if Gosu.button_down? Gosu::KbEscape
		@gracz.update
	end
end

Okno.new
