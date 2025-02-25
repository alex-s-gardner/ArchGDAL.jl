using Test
import GDAL
import ArchGDAL as AG

@testset "test_rasterband.jl" begin
    @testset "Test methods for rasterband" begin
        AG.read("data/utmsmall.tif") do dataset
            ds_result = """
            GDAL Dataset (Driver: GTiff/GeoTIFF)
            File(s): 
              data/utmsmall.tif

            Dataset (width x height): 100 x 100 (pixels)
            Number of raster bands: 1
              [GA_ReadOnly] Band 1 (Gray): 100 x 100 (UInt8)
            """
            @test sprint(print, dataset) == ds_result
            rb = AG.getband(dataset, 1)
            sprint(print, rb) == """
            [GA_ReadOnly] Band 1 (Gray): 100 x 100 (UInt8)
            blocksize: 100×81, nodata: -1.0e10, units: 1.0px + 0.0
            overviews: """
            @test sprint(print, AG.getdataset(rb)) == ds_result

            @test AG.getunittype(rb) == ""
            AG.setunittype!(rb, "ft")
            @test AG.getunittype(rb) == "ft"
            AG.setunittype!(rb, "")
            @test AG.getunittype(rb) == ""

            @test AG.getoffset(rb) == 0
            AG.setoffset!(rb, 10)
            @test AG.getoffset(rb) ≈ 10
            AG.setoffset!(rb, 0)
            @test AG.getoffset(rb) ≈ 0

            @test AG.getscale(rb) == 1
            AG.setscale!(rb, 0.5)
            @test AG.getscale(rb) ≈ 0.5
            AG.setscale!(rb, 2)
            @test AG.getscale(rb) ≈ 2
            AG.setscale!(rb, 1)
            @test AG.getscale(rb) ≈ 1

            @test isnothing(AG.getnodatavalue(rb))
            AG.setnodatavalue!(rb, -100)
            @test AG.getnodatavalue(rb) ≈ -100
            AG.deletenodatavalue!(rb)
            @test isnothing(AG.getnodatavalue(rb))

            AG.copy(dataset) do dest
                destband = AG.getband(dest, 1)
                AG.copywholeraster!(rb, destband)
                @test sprint(print, destband) == """
                [GA_Update] Band 1 (Gray): 100 x 100 (UInt8)
                    blocksize: 100×81, nodata: nothing, units: 1.0px + 0.0
                    overviews: """
                @test AG.noverview(destband) == 0
                AG.buildoverviews!(dest, Cint[2, 4, 8])
                @test AG.noverview(destband) == 3
                @test sprint(print, destband) == """
                [GA_Update] Band 1 (Gray): 100 x 100 (UInt8)
                    blocksize: 100×81, nodata: nothing, units: 1.0px + 0.0
                    overviews: (0) 50x50 (1) 25x25 (2) 13x13 
                               """
                @test AG.getcolorinterp(destband) == AG.GCI_GrayIndex
                AG.setcolorinterp!(destband, AG.GCI_RedBand)
                @test AG.getcolorinterp(destband) == AG.GCI_RedBand

                @test sprint(print, AG.sampleoverview(destband, 100)) == """
                [GA_Update] Band 1 (Gray): 13 x 13 (UInt8)
                    blocksize: 128×128, nodata: nothing, units: 1.0px + 0.0
                    overviews: """
                @test sprint(print, AG.sampleoverview(destband, 200)) == """
                [GA_Update] Band 1 (Gray): 25 x 25 (UInt8)
                    blocksize: 128×128, nodata: nothing, units: 1.0px + 0.0
                    overviews: """
                @test sprint(print, AG.sampleoverview(destband, 500)) == """
                [GA_Update] Band 1 (Gray): 25 x 25 (UInt8)
                    blocksize: 128×128, nodata: nothing, units: 1.0px + 0.0
                    overviews: """
                AG.sampleoverview(destband, 1000) do result
                    @test sprint(print, result) == """
                    [GA_Update] Band 1 (Gray): 50 x 50 (UInt8)
                        blocksize: 128×128, nodata: nothing, units: 1.0px + 0.0
                        overviews: """
                end
                @test sprint(print, AG.getmaskband(destband)) == """
                [GA_ReadOnly] Band 0 (Undefined): 100 x 100 (UInt8)
                    blocksize: 100×81, nodata: nothing, units: 1.0px + 0.0
                    overviews: """
                @test AG.maskflags(destband) == 1
                @test AG.maskflaginfo(rb) == (
                    all_valid = true,
                    per_dataset = false,
                    alpha = false,
                    nodata = false,
                )
                AG.createmaskband!(destband, 3)
                AG.getmaskband(destband) do maskband
                    @test sprint(print, maskband) == """
                    [GA_Update] Band 1 (Gray): 100 x 100 (UInt8)
                        blocksize: 100×81, nodata: nothing, units: 1.0px + 0.0
                        overviews: """
                end
                @test AG.maskflags(destband) == 3
                @test AG.maskflaginfo(destband) == (
                    all_valid = true,
                    per_dataset = true,
                    alpha = false,
                    nodata = false,
                )
                AG.fillraster!(destband, 3)
                AG.setcategorynames!(destband, ["foo", "bar"])
                @test AG.getcategorynames(destband) == ["foo", "bar"]

                AG.getoverview(destband, 0) do overview
                    return AG.regenerateoverviews!(
                        destband,
                        AG.AbstractRasterBand{UInt8}[
                            overview,
                            AG.getoverview(destband, 2),
                        ],
                    )
                end

                AG.createRAT() do rat
                    AG.setdefaultRAT!(destband, rat)
                    @test AG.getdefaultRAT(destband).ptr != rat.ptr
                end
                @test AG.getdefaultRAT(destband).ptr !=
                      GDAL.GDALRasterAttributeTableH(C_NULL)

                AG.getcolortable(destband) do ct
                    @test ct.ptr == GDAL.GDALColorTableH(C_NULL)
                end
                AG.createcolortable(AG.GPI_RGB) do ct
                    @test ct.ptr != GDAL.GDALColorTableH(C_NULL)
                    return AG.setcolortable!(destband, ct)
                end
                AG.clearcolortable!(destband)
                AG.getcolortable(destband) do ct
                    @test ct.ptr == GDAL.GDALColorTableH(C_NULL)
                end
            end
        end
    end
end
