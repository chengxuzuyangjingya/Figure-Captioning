pdfPath = '/storage_text/pmc/oa_pdf/00';
pdfsdir = dir(pdfPath); %第一层文件夹读取
for i = 1:length(pdfsdir)
  if(isequal(pdfsdir(i).name,'.')||isequal(pdfsdir(i).name,'..')||~pdfsdir(i).isdir)
    continue;
  end
  pdfdir = dir(fullfile(pdfPath, pdfsdir(i).name, '/*.pdf'));
  for j = 1:length(pdfdir)
    disp(pdfdir(j).name)
  end
  break
end