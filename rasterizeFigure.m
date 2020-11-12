function figureImage = rasterizeFigure(pdfPath, page, box, dpi, savepath)
% Render the given figure as a raster (pixel) image.
%
% pdfPath is the path to the pdf
% page is the page number the figure is located on
% box is the bounding box of the figure in the form [x1 y1 w h]
% dpi is the number of dots per inch to rasterize
% 

[~, paperName, ~] = fileparts(pdfPath);

page = num2str(page);%  数字转化为字符数组
imagename = [paperName '-p' page '-d' num2str(dpi) '.png'];
% savepath是extractFigures中调用时参数为pageImagePath的形参
imfile = fullfile(savepath, imagename);
% 下面应该是pdffigures处理后得到的page图片
if exist(imfile, 'file') ~= 2
    cmd = [...
    '-dSAFER ' ... % disable interactivity
    '-sDEVICE=png16m '...
    '-dFirstPage=' page ' -dLastPage=' page ' -r' num2str(dpi) ' '...
    '-o' imfile ' '...
    pdfPath ' '...
    ];
    disp(cmd);
    ghostscript(cmd);
end
pageImage = imread(imfile);
% 在pageImage即整个页面的图片中根据box定位到具体图片裁剪下来
figureImage = imcrop(pageImage, box);
end

