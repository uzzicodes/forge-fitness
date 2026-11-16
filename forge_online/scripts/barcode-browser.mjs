import {BrowserMultiFormatReader,DecodeHintType,BarcodeFormat} from '@zxing/library';
window.forgeReadBarcode=async function(image){
 if(typeof image!=='string'||!/^data:image\/(jpeg|png|webp);base64,/.test(image)||image.length>11500000)throw new Error('Use a barcode photo under 8 MB.');
 const hints=new Map([[DecodeHintType.POSSIBLE_FORMATS,[BarcodeFormat.EAN_13,BarcodeFormat.EAN_8,BarcodeFormat.UPC_A]],[DecodeHintType.TRY_HARDER,true]]);
 const reader=new BrowserMultiFormatReader(hints);
 try{const result=await reader.decodeFromImageUrl(image);return result.getText();}finally{reader.reset();}
};
