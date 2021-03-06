defmodule Identicon do
  @moduledoc """
  Creates an Identicon image for a username.  The input to Identicon.main/1
  is a username, and the output is an Identicon.

  An Identicon is a 5x5 grid of squares, with some of the squares coloured.
  The pattern and the colour is selected based on the input string.
  The Identicon image is 250px wide, 250px high.  Each of the grid squares
  is 50x wide, 50px high.

  The pattern is symmetrically mirrored around the center column; the
  two leftmost columns are a mirror of the two rightmost columns.

  Whenever we use the same input string, we should get the same identicon.
  This way we don't need to store an image with each user, we could generate
  the identicon on-the-fly each time a given user logs in.

  This project is from ["The Complete Elixir and Phoenix Bootcamp and Tutorial"](https://www.udemy.com/the-complete-elixir-and-phoenix-bootcamp-and-tutorial/learn/v4/overview) by Stephen Grider on www.udemy.com.  Stephen's official github repo for this
  exercise is [here](https://github.com/StephenGrider/ElixirCode/tree/master/identicon)

  This implementation uses the
  [EGD (Erlang Graphical Drawer)](http://www1.erlang.org/doc/man/egd.html)
  library to create the Identicon images.
  """

  @doc """
  Algorithm:
  - Take a string, and convert it to a list of 16 hex codes.
  - The first 3 numbers of the hex code list will form an RGB value.
    [145, 46, 200] will form a colour with Red=145, Green=46, Blue=200
  - With the 16 numbers, we will discard the last one.  That leaves us
    with 15 numbers, or 5 sets of 3.
      - Each row has 3 columns (the 4th and 5th columns are mirrors)
        and correspond to a number.
      - If the number is even, we will colour the square.  If it is odd
        we will not colour it.
  - Save the resulting image to a file.
  """
  @spec main(binary) :: :ok | no_return
  def main(input) do
    input
    |> hash_input
    |> pick_colour
    |> build_grid
    |> filter_odd_squares
    |> build_pixel_map
    |> draw_image
    |> save_image(input)

    crop_image(input)
  end


  @doc """
  Return a struct that contains a list of 16 numbers (each between 0-255),
  based on the contents of the input string.   We are going to generate our
  identicon based on this list of numbers.

  ## Parameters

    - input: String that represents a username

  ## Examples

      iex> Identicon.hash_input("asdf")
      %Identicon.Image{hex: [145, 46, 200, 3, 178, 206, 73, 228, 165, 65, 6, 141, 73, 90, 181, 112]}
  """
  @type rgb() :: 0..255
  @spec hash_input(binary) :: %Identicon.Image{hex: [rgb]}
  def hash_input(input) do
    hex = :crypto.hash(:md5, input)
    |> :binary.bin_to_list

    %Identicon.Image{hex: hex}
  end

  @doc """
  Grab the first 3 numbers from the hex list, and store them in the colour property.

  ## Examples

      iex> Identicon.pick_colour(%Identicon.Image{hex: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]})
      %Identicon.Image{colour: {1, 2, 3}, hex: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]}
  """
  @spec pick_colour(%Identicon.Image{hex: [rgb]}) :: %Identicon.Image{hex: [rgb], colour: {rgb, rgb, rgb}}
  def pick_colour(%Identicon.Image{hex: [red, green, blue| _tail]} = image) do
      # we convert colour from a list to a tuple, because each index
      # in the tuple has meaning.  1st spot is red, 2nd spot is green, etc.
      %Identicon.Image{ image | colour: {red, green, blue}}
  end

  @doc """
  Breaks the input into chunks of 3, mirrors them to create 5 columns,
  adds an index, and then store the result in the 'grid' attribute of image.

  The 1st value of each grid tuple is the mirrored row data, the 2nd value
  is the index.

  ## Examples

      iex> Identicon.build_grid(%Identicon.Image{hex: [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16]})
      %Identicon.Image{colour: nil, hex: [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16],
         grid: [{1, 0}, {2, 1}, {3, 2}, {2, 3}, {1, 4}, {4, 5}, {5, 6}, {6, 7},
           {5, 8}, {4, 9}, {7, 10}, {8, 11}, {9, 12}, {8, 13}, {7, 14}, {10, 15},
           {11, 16}, {12, 17}, {11, 18}, {10, 19}, {13, 20}, {14, 21}, {15, 22},
           {14, 23}, {13, 24}]
       }

  """
  @spec build_grid(%Identicon.Image{hex: [rgb]}) :: %Identicon.Image{hex: [rgb], grid: [{rgb, non_neg_integer}]}
  def build_grid(%Identicon.Image{hex: hex_list} = image) do
    grid =
      hex_list
      |> Enum.chunk(3)
      |> Enum.map(&mirror_row/1)
      |> List.flatten
      |> Enum.with_index

    %Identicon.Image{image | grid: grid}
  end

  @doc """
  ## Examples

      iex> Identicon.mirror_row([1, 2, 3])
      [1, 2, 3, 2, 1]
  """
  @spec mirror_row([rgb]) :: [rgb]
  def mirror_row([first, second | _tail] = row) do
    row ++ [second, first]
  end

  @doc """
  Filters the grid attribute, so that it only contains squares with
  even attribute values.  Odd values are removed.

  ## Examples

      iex> Identicon.filter_odd_squares(%Identicon.Image{grid: [{30, 0}, {31, 1}, {32, 2}, {33, 3}, {34, 4}, {35, 5}, {36, 6}, {37, 7}, {38, 8}, {39, 9}, {40, 10}, {41, 11}, {42, 12}, {43, 13}, {44, 14}, {45, 15}, {46, 16}, {47, 17}, {48, 18}, {49, 19}, {50, 20}, {51, 21}, {52, 22}, {53, 23}, {54, 24}]})
      %Identicon.Image{
        colour: nil, hex: nil,
        grid: [{30, 0}, {32, 2}, {34, 4}, {36, 6}, {38, 8}, {40, 10}, {42, 12},
               {44, 14}, {46, 16}, {48, 18}, {50, 20}, {52, 22}, {54, 24}]
      }
  """
  @spec filter_odd_squares(%Identicon.Image{grid: [{rgb, non_neg_integer}]}) :: %Identicon.Image{grid: [{rgb, non_neg_integer}]}
  def filter_odd_squares(%Identicon.Image{grid: grid} = image) do
    grid = Enum.filter grid, fn({code, _index}) ->
      rem(code, 2) == 0
    end

    %Identicon.Image{image | grid: grid}
  end


  @doc """
  Add a pixel_map attribute to our struct.  For each grid square that we want
  to colour, the pixel_map will contain a pair of points that we will later
  use to draw a rectangle.  Each pair of points gives the top-left and
  bottom-right (x,y) coordinates for a rectangle that will be drawn.

  ## Examples

      iex> Identicon.build_pixel_map(%Identicon.Image{grid: [{30, 0}, {32, 2}, {34, 4}, {36, 6}, {38, 8}, {40, 10}, {42, 12}, {44, 14}, {46, 16}, {48, 18}, {50, 20}, {52, 22}, {54, 24}]})
      %Identicon.Image{
        colour: nil, hex: nil,
        grid: [{30, 0}, {32, 2}, {34, 4}, {36, 6}, {38, 8}, {40, 10}, {42, 12},
               {44, 14}, {46, 16}, {48, 18}, {50, 20}, {52, 22}, {54, 24}],
        pixel_map: [{{0, 0}, {50, 50}}, {{100, 0}, {150, 50}}, {{200, 0}, {250, 50}},
          {{50, 50}, {100, 100}}, {{150, 50}, {200, 100}}, {{0, 100}, {50, 150}},
          {{100, 100}, {150, 150}}, {{200, 100}, {250, 150}}, {{50, 150}, {100, 200}},
          {{150, 150}, {200, 200}}, {{0, 200}, {50, 250}}, {{100, 200}, {150, 250}},
          {{200, 200}, {250, 250}}]
      }
  """
  @type x() :: 0..250
  @type y() :: 0..250
  @spec build_pixel_map(%Identicon.Image{grid: [{rgb, non_neg_integer}]}) :: %Identicon.Image{pixel_map: [{{x,y}, {x, y}}]}
  @identicon_square_pixels 50
  def build_pixel_map(%Identicon.Image{grid: grid} = image) do
    pixel_map = Enum.map grid, fn({_code, index}) ->
      horizontal = rem(index, 5) * @identicon_square_pixels
      vertical = div(index, 5) * @identicon_square_pixels

      top_left = {horizontal, vertical}
      bottom_right = {horizontal + @identicon_square_pixels, vertical + @identicon_square_pixels}

      {top_left, bottom_right}
    end

    %Identicon.Image{image | pixel_map: pixel_map}
  end

  @doc """
  Create an image with the [EGD](http://www1.erlang.org/doc/man/egd.html) library.  Return the rendered image.
  """
  @spec draw_image(%Identicon.Image{pixel_map: [{{x,y}, {x, y}}]}) :: binary()
  def draw_image(%Identicon.Image{colour: colour, pixel_map: pixel_map}) do
    box_dimension = @identicon_square_pixels * 50
    image = :egd.create(box_dimension, box_dimension)
    fill_colour = :egd.color(colour)

    Enum.each pixel_map, fn({start, stop}) ->
      :egd.filledRectangle(image, start, stop, fill_colour)
    end

    :egd.render(image)
  end

  @doc """
  Save image as a .PNG file.  We use the original string input as the filename
  that we save the image to.

  ## Parameters

    - input: The filename that we save the image to
  """
  @spec save_image(binary, binary) :: :ok | no_return
  def save_image(image, input) do
    File.write("#{input}.png", image)
  end

  @doc """
  The default image is 2500x2500, with the top-left 250x250 pixels containing
  our image.  This function crops out the 250x250 pixels starting at the
  top-left corner, and stores the result in a file of the same name.

  ## Parameters

    - input: The filename that we save the image to (without any suffix)
  """
  @spec crop_image(binary) :: :ok | no_return
  def crop_image(input) do
    total_square_pixels = @identicon_square_pixels * 5
    image_path = Path.join(__DIR__, "../#{input}.png")
    ExMagick.init!()
    |> ExMagick.image_load!(image_path)
    |> ExMagick.crop!(0, 0, total_square_pixels, total_square_pixels)
    |> ExMagick.image_dump!(image_path)   # overwrites previous image

    :ok
  end
end
