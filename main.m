conf = setConf();

% Extract figures from PDFs
resultnum_w = 0;  %计算共有多少张折线图，包含直接notext的折线图
resulttextnum_w = 0; %计算共有多少张折线图，不包含notext的折线图
cutnum_w = 0;
json_num = 0;
pdfs = {}; %存储所有文件夹的pdf
pdfsdir = dir(conf.pdfPath);
for i = 1:length(pdfsdir)
    if(isequal(pdfsdir(i).name,'.')||isequal(pdfsdir(i).name,'..')||~pdfsdir(i).isdir)
      continue;
    end
    pdfs = arrayfun(@(f) f.name, dir(fullfile(conf.pdfPath, pdfsdir(i).name, '*.pdf')), 'UniformOutput', false);

    % figureNames表示的是提取出来的大图存储数组
    filename = pdfsdir(i).name
    figureNames = extractFigures(pdfs, conf,  filename);
    % Extract subfigures
    %  将子图像export_fig提取至subfigure-vis文件中
    if conf.extractSubfigures
        subfigureNames = {};
        for n = 1:length(figureNames)
            figureName = figureNames{n};
            fig = Figure.fromName(figureName, conf);
            try
                subfigures = findSubfigures(fig);
            catch
                continue;
            end
            
            set(gcf, 'Position', [1 1 500 500]);
    %        imwrite(fig.image, fullfile(conf.subfigureVisPath, [figureName '.png']));

    %export_fig就是将可分割大图分割子图的地方框住并存储起来
            disp(figureName)
            export_fig(fullfile(conf.subfigureVisPath, figureName), '-native');
            
    %  将findSubfigures中的图像写入figure-images文件夹中
    %  将findSubfigures获得的json文件存入figure-text文件中
            for m = 1:length(subfigures)
                
    %  figureName格式是papername-fig01,因此subfigureName格式是papername-fig01-subfig01
                subfigureName = sprintf('%s-subfig%.02d', figureName, m);
                try
                    imwrite(subfigures(m).image, fullfile(conf.figureImagePath, [subfigureName '.png']));
                catch
                    continue;
                end 
                savejson('', subfigures(m).textBoxes, fullfile(conf.textPath, [subfigureName '.json']));
                subfigureNames = [subfigureNames subfigureName];
            end
        end
    %  之前的figureNames表示文献中的大图,到此之后figureNames表示的是分割后的子图的数组
        figureNames = subfigureNames;
    end

    % Classify figures
    net = caffe.Net(conf.figureClassNet, conf.figureClassWeights, 'test');
    values = {'Bar Chart', 'Graph Plot', 'Node Diagram', 'Other', 'Scatterplot', 'Table', 'Equation'};
    keys = 0:(length(values)-1);
    idxToClass = containers.Map(keys,values);

    for n = 1:length(figureNames)
        figureName = figureNames{n};
        fprintf('Classifying %s\n', figureName);
        fig = Figure.fromName(figureName, conf);
        tenCropImage = prepareImage(fig.image, conf.figureClassMean);
        cropPredictions = net.forward({tenCropImage});
        classPredictions = mean(cropPredictions{1}, 2);
        savejson('',classPredictions,fullfile(conf.classPredictionPath,[figureName '.json']));
        classProbs = loadjson(fullfile(conf.classPredictionPath,[figureName '.json']));
        [sortedProbs, order] = sort(classProbs, 'descend');
        if isequal(idxToClass(order(1)-1),'Graph Plot')        
            resultnum_w = resultnum_w + 1;
        end

    end
    caffe.reset_all();
    textname = '/home/d2zhang/wutlab/figureseer/data/output/result.txt';
    fid3 = fopen(textname,'w');
    fprintf(fid3,'%d\n',resultnum_w);


    % Parse figures
    syms figure_first
    syms figure_second
    syms givelegends
    syms giveimage
    %用于parsechart的变量
    for n = 1:length(figureNames)
        figureName = figureNames{n};
    %  fig包含textBoxes和image
        fig = Figure.fromName(figureName, conf);
    %    v = get(fig, 'textBoxes');
    %    disp(v)
        classProbs = loadjson(fullfile(conf.classPredictionPath,[figureName '.json']));
        [sortedProbs, order] = sort(classProbs, 'descend');
        if isequal(idxToClass(order(1)-1),'Graph Plot')
            fprintf('Parsing %s\n', figureName);  
            [result, figure_first, figure_second, givelegends, giveimage, resulttextnum_w, cutnum_w] = parseChart(fig, figureName, figure_first, figure_second, givelegends, giveimage, resulttextnum_w, cutnum_w, conf);
    %    disp(figure_first)
            if isfield(result, 'error')
                disp(result.error);
                continue;
            end
            result.xAxis = rmfield(struct(result.xAxis), 'model'); % Can't save matlab GLM type to Json
            result.yAxis = rmfield(struct(result.yAxis), 'model');
            try
                savejson('', result, fullfile(conf.resultJsonPath, [figureName '.json']));
                jsonname = '/home/d2zhang/wutlab/figureseer/data/output/jsonnum.txt';
                fid2 = fopen(jsonname,'w');
                json_num = json_num + 1;
                fprintf(fid2,'%d\n',json_num);
            catch
                results.error = 'Failed save json';
                continue;
            end
            export_fig(fullfile(conf.resultImagePath, [figureName '-result.png']),'-native');
            imwrite(fig.image, fullfile(conf.resultImagePath, [figureName '-result.png']));      
        end
        
    end
    % Output results PDFs
    for n = 1:length(pdfs)
        paperName = pdfs{n}(1:end-4);
        outputResultsPdf(paperName, conf);
    end
end
